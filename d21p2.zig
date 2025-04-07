const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ByteList = ArrayList(u8);

const NUMPAD_LAYOUT =
    \\789
    \\456
    \\123
    \\ 0A
;

const DPAD_LAYOUT =
    \\ ^A
    \\<v>
;

fn contains_char(bytes: []const u8, value: u8) bool {
    for (bytes) |b| {
        if (b == value) {
            return true;
        }
    }
    return false;
}

fn chars_until(bytes: []const u8, value: u8) usize {
    var result: usize = 0;
    while (result < bytes.len) : (result += 1) {
        if (bytes[result] == value) return result;
    }

    unreachable;
}

fn count_chars(bytes: []const u8, value: u8) usize {
    var result: usize = 0;
    for (bytes) |b| {
        if (b == value) {
            result += 1;
        }
    }

    return result;
}

const KeyPad = struct {
    layout: []const u8,
    cols: usize,
    rows: usize,

    fn init(layout: []const u8) KeyPad {
        comptime {
            std.debug.assert(contains_char(layout, 'A'));

            const cols = chars_until(layout, '\n');
            const rows = count_chars(layout, '\n') + 1;

            std.debug.assert(layout.len == rows * (cols + 1) - 1);

            return KeyPad{ .layout = layout, .cols = cols, .rows = rows };
        }
    }

    fn at(self: KeyPad, col: usize, row: usize) u8 {
        return self.layout[self.index(col, row)];
    }

    fn pos_of(self: KeyPad, value: u8) Position {
        for (self.layout, 0..) |b, i| {
            if (b == value) {
                const col = i % (self.cols + 1);
                const row = i / (self.cols + 1);
                return Position{ .col = col, .row = row };
            }
        }

        unreachable;
    }

    inline fn index(self: KeyPad, col: usize, row: usize) usize {
        return row * (self.cols + 1) + col;
    }
};

const Position = struct { col: usize, row: usize };

const NUMPAD = KeyPad.init(NUMPAD_LAYOUT);
const DPAD = KeyPad.init(DPAD_LAYOUT);

test "numpad contains A at 2,3" {
    try std.testing.expectEqual('A', NUMPAD.at(2, 3));
    try std.testing.expectEqual(Position{ .col = 2, .row = 3 }, NUMPAD.pos_of('A'));
}

const QueueItem = struct {
    from: Position,
    my_moves_so_far: []const u8,
    target_moves_to_perform: []const u8,

    fn score(self: QueueItem) usize {
        return self.my_moves_so_far.len;
    }
};

const Deque = struct {
    list: *ArrayList(QueueItem),

    fn init(allocator: Allocator) Deque {
        const list_ptr = allocator.create(ArrayList(QueueItem)) catch unreachable;
        list_ptr.* = ArrayList(QueueItem).init(allocator);
        return Deque{ .list = list_ptr };
    }

    inline fn indexToPush(self: *Deque, item: QueueItem) usize {
        var start: usize = 0;
        var end: usize = self.list.items.len; // exclusive
        var cur: usize = start;
        while (start < end) {
            cur = start + ((end - start) / 2);
            if (self.list.items[cur].score() == item.score()) return cur;

            if (self.list.items[cur].score() < item.score()) {
                end = cur;
            } else {
                start = cur + 1;
            }
        }

        return cur;
    }

    fn push(self: *Deque, item: QueueItem) void {
        self.list.insert(self.indexToPush(item), item) catch unreachable;
    }

    fn pop(self: *Deque) ?QueueItem {
        return self.list.pop();
    }
};

fn combine(allocator: Allocator, first: []const u8, second: []const u8) []u8 {
    var byteList = ByteList.init(allocator);
    byteList.appendSlice(first) catch unreachable;
    byteList.appendSlice(second) catch unreachable;
    return byteList.items;
}

const CacheKey = struct {
    from: Position,
    moves_on_target: []const u8,
};

const CacheKeyContext = struct {
    pub fn hash(_: CacheKeyContext, key: CacheKey) u64 {
        var h = std.hash.Fnv1a_64.init();
        std.hash.autoHash(&h, key.from);
        h.update(key.moves_on_target);
        return h.final();
    }

    pub fn eql(_: CacheKeyContext, a: CacheKey, b: CacheKey) bool {
        return a.from.col == b.from.col and a.from.row == b.from.row and std.mem.eql(u8, a.moves_on_target, b.moves_on_target);
    }
};

const Cache = std.HashMap(CacheKey, []const u8, CacheKeyContext, 80);

const Target = struct {
    ptr: *anyopaque,
    movesToPerformFn: *const fn (ptr: *anyopaque, action: u8) error{OutOfMemory}![]const u8,
    performFn: *const fn (ptr: *anyopaque, move: u8) void,
    controls: KeyPad,

    fn movesToPerform(self: Target, action: u8) ![]const u8 {
        return self.movesToPerformFn(self.ptr, action);
    }

    fn perform(self: Target, move: u8) void {
        self.performFn(self.ptr, move);
    }
};

const Robot = struct {
    const Self = Robot;
    target: Target,
    cur_pos: Position,
    panic: Position,
    performed: *ByteList,
    cache: *Cache,
    allocator: Allocator,

    fn init(allocator: Allocator, target: Target) !Self {
        const list_ptr = try allocator.create(ByteList);
        list_ptr.* = ByteList.init(allocator);
        const keypad: KeyPad = target.controls;
        const panic = keypad.pos_of(' ');
        const cur_pos = keypad.pos_of('A');
        const cache_ptr = try allocator.create(Cache);
        cache_ptr.* = Cache.init(allocator);
        return Self{ .target = target, .cur_pos = cur_pos, .panic = panic, .performed = list_ptr, .cache = cache_ptr, .allocator = allocator };
    }

    fn movesByPositions(self: *Self, dest: Position, begin: Position) ![]const u8 {
        const allocator = self.allocator;
        // std.debug.print("movesByPositions(dest: {d},{d} , from: {d},{d})\n", .{ dest.col, dest.row, begin.col, begin.row });
        var out = ByteList.init(allocator);
        if (dest.col == begin.col and dest.row == begin.row) {
            try out.append('A');
            return out.items;
        }
        const panic = self.panic;
        var cur = begin;
        const requires_both_vertical_and_horizontal = cur.col != dest.col and cur.row != dest.row;
        if (cur.col != panic.col or dest.row != panic.row) {
            // vertical first
            while (cur.col != dest.col or cur.row != dest.row) {
                if (cur.row > dest.row) {
                    try out.append('^');
                    cur = Position{ .col = cur.col, .row = cur.row - 1 };
                } else if (cur.row < dest.row) {
                    try out.append('v');
                    cur = Position{ .col = cur.col, .row = cur.row + 1 };
                } else if (cur.col < dest.col) {
                    try out.append('>');
                    cur = Position{ .col = cur.col + 1, .row = cur.row };
                } else if (cur.col > dest.col) {
                    try out.append('<');
                    cur = Position{ .col = cur.col - 1, .row = cur.row };
                } else {
                    unreachable;
                }
            }
            try out.append('A');
        }

        cur = begin;
        if (cur.row != panic.row or dest.col != panic.col and requires_both_vertical_and_horizontal) {
            if (out.items.len > 0) {
                try out.append('\n');
            }
            // horizontal first
            while (cur.col != dest.col or cur.row != dest.row) {
                if (cur.col < dest.col) {
                    try out.append('>');
                    cur = Position{ .col = cur.col + 1, .row = cur.row };
                } else if (cur.col > dest.col) {
                    try out.append('<');
                    cur = Position{ .col = cur.col - 1, .row = cur.row };
                } else if (cur.row < dest.row) {
                    try out.append('v');
                    cur = Position{ .col = cur.col, .row = cur.row + 1 };
                } else if (cur.row > dest.row) {
                    try out.append('^');
                    cur = Position{ .col = cur.col, .row = cur.row - 1 };
                } else {
                    unreachable;
                }
            }
            try out.append('A');
        }
        // std.debug.print("movesByPositions(dest: {d},{d} , from: {d},{d}) = {s}\n", .{ dest.col, dest.row, begin.col, begin.row, out.items });
        const result = out.items;
        return result;
    }

    fn movesToPerformOnMe(self: *Self, moves_on_target: []const u8) []const u8 {
        const allocator = self.allocator;
        const key = CacheKey{ .moves_on_target = moves_on_target, .from = self.cur_pos };
        if (self.cache.get(key)) |value| {
            return value;
        }

        var out = ByteList.init(allocator);
        const keypad: KeyPad = self.target.controls;

        var deque = Deque.init(allocator);
        deque.push(.{ .from = self.cur_pos, .my_moves_so_far = "", .target_moves_to_perform = moves_on_target });

        var min_moves_len: usize = std.math.maxInt(usize);

        while (deque.pop()) |item| {
            // std.debug.print("deque pop: moves_so_far: {s}, target_moves_to_perform: {s}\n", .{ item.my_moves_so_far, item.target_moves_to_perform });
            if (item.target_moves_to_perform.len == 0) {
                if (item.my_moves_so_far.len <= min_moves_len) {
                    if (out.items.len != 0) {
                        out.append('\n') catch unreachable;
                    }

                    out.appendSlice(item.my_moves_so_far) catch unreachable;
                    min_moves_len = item.my_moves_so_far.len;
                    continue;
                } else {
                    break;
                }
            }

            const next_move = item.target_moves_to_perform[0];
            const remaining_moves = item.target_moves_to_perform[1..];
            const dest = keypad.pos_of(next_move);
            const moves_by_pos = self.movesByPositions(dest, item.from) catch unreachable;
            var line_tokenizer = std.mem.tokenizeScalar(u8, moves_by_pos, '\n');

            while (line_tokenizer.next()) |my_moves| {
                deque.push(.{ .target_moves_to_perform = remaining_moves, .my_moves_so_far = combine(allocator, item.my_moves_so_far, my_moves), .from = dest });
            }
        }

        // std.debug.print("movesToPerformOnMe({s}) = {s}\n", .{ moves_on_target, out.items });
        const result = out.items;
        self.cache.put(key, result) catch unreachable;
        return result;
    }

    fn movesToPerform(self: *Self, action: u8) ![]const u8 {
        const allocator = self.allocator;
        const moves_set_to_peform_on_target = try self.target.movesToPerform(action);

        var my_moves_tokenizer = std.mem.tokenizeScalar(u8, moves_set_to_peform_on_target, '\n');

        var out = ByteList.init(allocator);
        var min_len: usize = std.math.maxInt(usize);

        while (my_moves_tokenizer.next()) |moves_on_target| {
            const moves_set_to_perform_on_me = self.movesToPerformOnMe(moves_on_target);

            var line_tokenizer = std.mem.tokenizeScalar(u8, moves_set_to_perform_on_me, '\n');
            while (line_tokenizer.next()) |moves_to_peform_on_me| {
                if (moves_to_peform_on_me.len > min_len) {
                    continue;
                }

                if (moves_to_peform_on_me.len < min_len) {
                    min_len = moves_to_peform_on_me.len;
                    out.clearRetainingCapacity();
                }

                if (out.items.len > 0) {
                    out.append('\n') catch unreachable;
                }

                out.appendSlice(moves_to_peform_on_me) catch unreachable;
            }
        }

        const result = out.items;
        return result;
    }

    fn perform(self: *Self, move: u8) void {
        switch (move) {
            '<' => self.cur_pos = Position{ .col = self.cur_pos.col - 1, .row = self.cur_pos.row },
            '>' => self.cur_pos = Position{ .col = self.cur_pos.col + 1, .row = self.cur_pos.row },
            '^' => self.cur_pos = Position{ .col = self.cur_pos.col, .row = self.cur_pos.row - 1 },
            'v' => self.cur_pos = Position{ .col = self.cur_pos.col, .row = self.cur_pos.row + 1 },
            'A' => {
                const keypad: KeyPad = self.target.controls;
                const value = keypad.at(self.cur_pos.col, self.cur_pos.row);
                self.target.perform(value);
            },
            else => {
                std.debug.print("Trying to perform invalid move: {c}\n", .{move});
                unreachable;
            },
        }
        self.performed.append(move) catch unreachable;
    }

    fn performAll(self: *Self, moves: []const u8) void {
        for (moves) |move| {
            self.perform(move);
        }
    }

    fn typeErasedMovesToPerform(ptr: *anyopaque, action: u8) ![]const u8 {
        const robot_ptr: *Robot = @ptrCast(@alignCast(ptr));
        return robot_ptr.movesToPerform(action);
    }

    fn typeErasedPerform(ptr: *anyopaque, move: u8) void {
        const robot_ptr: *Robot = @ptrCast(@alignCast(ptr));
        return robot_ptr.perform(move);
    }

    fn asTarget(self: *Robot) Target {
        return Target{ .ptr = self, .movesToPerformFn = typeErasedMovesToPerform, .performFn = typeErasedPerform, .controls = DPAD };
    }
};

const Door = struct {
    performed: *ByteList,
    allocator: Allocator,

    fn init(allocator: Allocator) !Door {
        const list_ptr = try allocator.create(ByteList);
        list_ptr.* = ByteList.init(allocator);
        return Door{ .performed = list_ptr, .allocator = allocator };
    }

    fn movesToPerform(self: *Door, action: u8) ![]const u8 {
        const allocator = self.allocator;
        var result = try allocator.alloc(u8, 1);
        result[0] = action;
        const out = result;
        return out;
    }

    fn controls(_: *Door) KeyPad {
        return NUMPAD;
    }

    fn perform(self: *Door, move: u8) void {
        self.performed.append(move) catch unreachable;
    }

    fn typeErasedMovesToPerform(ptr: *anyopaque, action: u8) ![]const u8 {
        const robot_ptr: *Door = @ptrCast(@alignCast(ptr));
        return robot_ptr.movesToPerform(action);
    }

    fn typeErasedPerform(ptr: *anyopaque, move: u8) void {
        const robot_ptr: *Door = @ptrCast(@alignCast(ptr));
        return robot_ptr.perform(move);
    }

    fn asTarget(self: *Door) Target {
        return Target{ .ptr = self, .movesToPerformFn = typeErasedMovesToPerform, .performFn = typeErasedPerform, .controls = NUMPAD };
    }
};

const Setup = struct {
    door: *Door,
    doorRobot: *Robot,
    firstRobot: *Robot,
    secondRobot: *Robot,
    allocator: Allocator,

    fn init(allocator: Allocator) !Setup {
        const door_ptr = try allocator.create(Door);
        door_ptr.* = try Door.init(allocator);
        const door_robot_ptr = try allocator.create(Robot);
        door_robot_ptr.* = try Robot.init(allocator, door_ptr.asTarget());
        const first_robot_ptr = try allocator.create(Robot);
        first_robot_ptr.* = try Robot.init(allocator, door_robot_ptr.asTarget());
        const second_robot_ptr = try allocator.create(Robot);
        second_robot_ptr.* = try Robot.init(allocator, first_robot_ptr.asTarget());

        return Setup{
            .door = door_ptr,
            .doorRobot = door_robot_ptr,
            .firstRobot = first_robot_ptr,
            .secondRobot = second_robot_ptr,
            .allocator = allocator,
        };
    }

    fn complexity(self: *Setup, codes: []const u8) !u64 {
        var result: u64 = 0;
        var line_tokenizer = std.mem.tokenizeScalar(u8, codes, '\n');
        var byte_list = ByteList.init(self.allocator);
        while (line_tokenizer.next()) |moves| {
            for (moves) |move| {
                const mtp = try self.secondRobot.movesToPerform(move);
                var tokenizer = std.mem.tokenizeScalar(u8, mtp, '\n');
                const first_move = tokenizer.next().?;
                try byte_list.appendSlice(first_move);
                self.secondRobot.performAll(first_move);
            }
            const len: u64 = @intCast(byte_list.items.len);
            const code_num = try std.fmt.parseInt(u64, moves[0 .. moves.len - 1], 10);

            result += len * code_num;
            // std.debug.print("{s}\n", .{moves});
            // std.debug.print("door_robot: {s}\n", .{self.doorRobot.performed.items});
            // std.debug.print("first_robot: {s}\n", .{self.firstRobot.performed.items});
            // std.debug.print("second_robot: {s}\n", .{self.secondRobot.performed.items});
            byte_list.clearRetainingCapacity();
            self.doorRobot.performed.clearRetainingCapacity();
            self.firstRobot.performed.clearRetainingCapacity();
            self.secondRobot.performed.clearRetainingCapacity();
        }

        return result;
    }
};

const INPUT = @embedFile("inputs/day21.txt");
test "main input complexity for 3 robots in between" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    var setup = try Setup.init(allocator);
    const complexity = try setup.complexity(INPUT);

    try std.testing.expectEqual(217662, complexity);
}

test "sample complexity" {
    const codes =
        \\029A
        \\980A
        \\179A
        \\456A
        \\379A
    ;

    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    var setup = try Setup.init(allocator);
    const complexity = try setup.complexity(codes);

    try std.testing.expectEqual(126384, complexity);
}
