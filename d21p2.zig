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
    return byteList.toOwnedSlice() catch unreachable;
}

const CacheByPositionsKey = struct {
    from: Position,
    dest: Position,
};

const CacheByPositions = std.AutoHashMap(CacheByPositionsKey, []const u8);

const CacheByMovesOnTargetKey = struct {
    from: Position,
    moves_on_target: []const u8,

    pub fn hash(self: CacheByMovesOnTargetKey) u64 {
        var hasher = std.hash.Fnv1a_64.init();
        std.hash.autoHash(&hasher, self.from);
        hasher.update(self.moves_on_target);
        return hasher.final();
    }

    pub fn eql(self: CacheByMovesOnTargetKey, other: CacheByMovesOnTargetKey) bool {
        return self.from.col == other.from.col and self.from.row == other.from.row and std.mem.eql(u8, self.moves_on_target, other.moves_on_target);
    }
};

const CacheByMovesOnTargetContext = struct {
    pub fn hash(_: CacheByMovesOnTargetContext, key: CacheByMovesOnTargetKey) u64 {
        return key.hash();
    }

    pub fn eql(_: CacheByMovesOnTargetContext, key1: CacheByMovesOnTargetKey, key2: CacheByMovesOnTargetKey) bool {
        return key1.eql(key2);
    }
};

const CacheByMovesOnTarget = std.HashMap(CacheByMovesOnTargetKey, []const u8, CacheByMovesOnTargetContext, 80);
const CacheKey = struct {
    dest: u8,
    from: u8,
};
const MovesCache = std.AutoHashMap(CacheKey, []const u8);

const Target = struct {
    ptr: *anyopaque,
    movesToPerformFn: *const fn (ptr: *anyopaque, allocator: Allocator, dest: u8, from: u8) error{OutOfMemory}![]const u8,
    controls: KeyPad,

    fn movesToPerform(self: Target, allocator: Allocator, dest: u8, from: u8) ![]const u8 {
        return self.movesToPerformFn(self.ptr, allocator, dest, from);
    }
};

const ArenaAllocator = std.heap.ArenaAllocator;

const Robot = struct {
    const Self = Robot;
    target: Target,
    cur_pos: Position,
    panic: Position,
    performed: *ByteList,
    cache_by_positions: *CacheByPositions,
    cache_by_moves_on_target: *CacheByMovesOnTarget,
    moves_cache: *MovesCache,
    allocator: Allocator,

    fn init(allocator: Allocator, target: Target, cache_by_positions: *CacheByPositions) !Self {
        const list_ptr = try allocator.create(ByteList);
        list_ptr.* = ByteList.init(allocator);
        const keypad: KeyPad = target.controls;
        const panic = keypad.pos_of(' ');
        const cur_pos = keypad.pos_of('A');
        const cache_by_moves_on_target_ptr = try allocator.create(CacheByMovesOnTarget);
        cache_by_moves_on_target_ptr.* = CacheByMovesOnTarget.init(allocator);
        const moves_cache_ptr = try allocator.create(MovesCache);
        moves_cache_ptr.* = MovesCache.init(allocator);
        return Self{ .target = target, .cur_pos = cur_pos, .panic = panic, .performed = list_ptr, .cache_by_positions = cache_by_positions, .cache_by_moves_on_target = cache_by_moves_on_target_ptr, .moves_cache = moves_cache_ptr, .allocator = allocator };
    }

    fn deinit(self: *Robot) void {
        self.performed.deinit();
        self.allocator.destroy(self.performed);

        // loop through caches and free slices in keys and values
        var iterator = self.cache_by_moves_on_target.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*.moves_on_target);
            self.allocator.free(entry.value_ptr.*);
        }

        var moves_cache_iterator = self.moves_cache.iterator();
        while (moves_cache_iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }

        self.cache_by_moves_on_target.deinit();
        self.allocator.destroy(self.cache_by_moves_on_target);
        self.moves_cache.deinit();
        self.allocator.destroy(self.moves_cache);
    }

    fn movesByPositions(self: *Self, allocator: Allocator, dest: Position, begin: Position) ![]const u8 {
        const key = CacheByPositionsKey{ .from = begin, .dest = dest };
        if (self.cache_by_positions.get(key)) |value| {
            return value;
        }
        // std.debug.print("movesByPositions(dest: {d},{d} , from: {d},{d})\n", .{ dest.col, dest.row, begin.col, begin.row });
        var out = ByteList.init(allocator);
        if (dest.col == begin.col and dest.row == begin.row) {
            try out.append('A');
            const result = out.items;
            try self.cache_by_positions.put(key, try self.allocator.dupe(u8, result));
            return result;
        }
        const panic = self.panic;
        var cur = begin;
        const requires_both_vertical_and_horizontal = cur.col != dest.col and cur.row != dest.row;
        const only_give_one_option = self.target.controls.at(0, 0) == ' '; // DPAD
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

        if (!only_give_one_option or out.items.len == 0) {
            cur = begin;
            if ((cur.row != panic.row or dest.col != panic.col) and requires_both_vertical_and_horizontal) {
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
        }
        // std.debug.print("movesByPositions(dest: {d},{d} , from: {d},{d}) = {s}\n", .{ dest.col, dest.row, begin.col, begin.row, out.items });
        const result = out.items;
        try self.cache_by_positions.put(key, try self.allocator.dupe(u8, result));
        return result;
    }

    fn movesUnitToPerformOnMe(self: *Self, allocator: Allocator, moves_unit_on_target: []const u8) []const u8 {
        const key = CacheByMovesOnTargetKey{ .from = self.cur_pos, .moves_on_target = self.allocator.dupe(u8, moves_unit_on_target) catch unreachable };
        if (self.cache_by_moves_on_target.get(key)) |value| {
            self.allocator.free(key.moves_on_target);
            return value;
        }

        var out = ByteList.init(allocator);
        const keypad: KeyPad = self.target.controls;

        var deque = Deque.init(allocator);
        deque.push(.{ .from = self.cur_pos, .my_moves_so_far = "", .target_moves_to_perform = moves_unit_on_target });

        var min_moves_len: usize = std.math.maxInt(usize);

        while (deque.pop()) |item| {
            // std.debug.print("deque pop in unit: moves_so_far: {s}, target_moves_to_perform: {s}\n", .{ item.my_moves_so_far, item.target_moves_to_perform });
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
            const moves_by_pos = self.movesByPositions(allocator, dest, item.from) catch unreachable;
            var line_tokenizer = std.mem.tokenizeScalar(u8, moves_by_pos, '\n');

            while (line_tokenizer.next()) |my_moves| {
                deque.push(.{ .target_moves_to_perform = remaining_moves, .my_moves_so_far = combine(allocator, item.my_moves_so_far, my_moves), .from = dest });
            }
        }

        const result = out.items;
        if (self.cache_by_moves_on_target.get(key)) |_| {
            self.allocator.free(key.moves_on_target);
        } else {
            self.cache_by_moves_on_target.put(key, self.allocator.dupe(u8, result) catch unreachable) catch unreachable;
        }
        return result;
    }

    fn movesToPerformOnMe(self: *Self, allocator: Allocator, moves_on_target: []const u8) []const u8 {
        // std.debug.print("movesToPerformOnMe({s})\n", .{moves_on_target});
        const key = CacheByMovesOnTargetKey{ .from = self.cur_pos, .moves_on_target = self.allocator.dupe(u8, moves_on_target) catch unreachable };
        if (self.cache_by_moves_on_target.get(key)) |value| {
            self.allocator.free(key.moves_on_target);
            return value;
        }

        var out = ByteList.init(allocator);

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

            const index_of_A = std.mem.indexOfScalar(u8, item.target_moves_to_perform, 'A');
            var next_move_unit = item.target_moves_to_perform;
            var remaining_moves: []const u8 = "";
            if (index_of_A) |i| {
                next_move_unit = item.target_moves_to_perform[0 .. i + 1];
                remaining_moves = item.target_moves_to_perform[i + 1 ..];
            }
            const moves_by_pos = self.movesUnitToPerformOnMe(allocator, next_move_unit);
            var line_tokenizer = std.mem.tokenizeScalar(u8, moves_by_pos, '\n');

            while (line_tokenizer.next()) |my_moves| {
                deque.push(.{ .target_moves_to_perform = remaining_moves, .my_moves_so_far = combine(allocator, item.my_moves_so_far, my_moves), .from = self.cur_pos });
            }
        }

        // std.debug.print("movesToPerformOnMe({s}) = {s}\n", .{ moves_on_target, out.items });
        const result = out.items;
        if (self.cache_by_moves_on_target.get(key)) |_| {
            self.allocator.free(key.moves_on_target);
        } else {
            self.cache_by_moves_on_target.put(key, self.allocator.dupe(u8, result) catch unreachable) catch unreachable;
        }
        return result;
    }

    fn movesToPerform(self: *Self, allocator: Allocator, dest: u8, from: u8) ![]const u8 {
        const key = CacheKey{ .dest = dest, .from = from };
        if (self.moves_cache.get(key)) |value| {
            return value;
        }

        const moves_set_to_peform_on_target = try self.target.movesToPerform(allocator, dest, from);

        var my_moves_tokenizer = std.mem.tokenizeScalar(u8, moves_set_to_peform_on_target, '\n');

        var out = ByteList.init(allocator);
        var min_len: usize = std.math.maxInt(usize);

        while (my_moves_tokenizer.next()) |moves_on_target| {
            const moves_set_to_perform_on_me = self.movesToPerformOnMe(allocator, moves_on_target);

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
        try self.moves_cache.put(key, try self.allocator.dupe(u8, result));
        return result;
    }

    fn typeErasedMovesToPerform(ptr: *anyopaque, allocator: Allocator, dest: u8, from: u8) ![]const u8 {
        const robot_ptr: *Robot = @ptrCast(@alignCast(ptr));
        return robot_ptr.movesToPerform(allocator, dest, from);
    }

    fn asTarget(self: *Robot) Target {
        return Target{ .ptr = self, .movesToPerformFn = typeErasedMovesToPerform, .controls = DPAD };
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

    fn deinit(self: *Door) void {
        self.performed.deinit();
        self.allocator.destroy(self.performed);
    }

    fn movesToPerform(_: *Door, allocator: Allocator, dest: u8, _: u8) ![]const u8 {
        var result = try allocator.alloc(u8, 1);
        result[0] = dest;
        const out = result;
        return out;
    }

    fn controls(_: *Door) KeyPad {
        return NUMPAD;
    }

    fn typeErasedMovesToPerform(ptr: *anyopaque, allocator: Allocator, dest: u8, from: u8) ![]const u8 {
        const door_ptr: *Door = @ptrCast(@alignCast(ptr));
        return door_ptr.movesToPerform(allocator, dest, from);
    }

    fn asTarget(self: *Door) Target {
        return Target{ .ptr = self, .movesToPerformFn = typeErasedMovesToPerform, .controls = NUMPAD };
    }
};

const RobotChain = ArrayList(*Robot);

const Setup = struct {
    door: *Door,
    robot_chain: *RobotChain,
    cache_by_positions_numpad: *CacheByPositions,
    cache_by_positions_dpad: *CacheByPositions,
    allocator: Allocator,

    fn init(allocator: Allocator, robot_chain_len: u8) !Setup {
        const door_ptr = try allocator.create(Door);
        door_ptr.* = try Door.init(allocator);

        const cache_by_positions_numpad_ptr = try allocator.create(CacheByPositions);
        cache_by_positions_numpad_ptr.* = CacheByPositions.init(allocator);

        const cache_by_positions_dpad_ptr = try allocator.create(CacheByPositions);
        cache_by_positions_dpad_ptr.* = CacheByPositions.init(allocator);

        const robot_chain_ptr = try allocator.create(RobotChain);
        robot_chain_ptr.* = try RobotChain.initCapacity(allocator, robot_chain_len);

        var target = door_ptr.asTarget();
        for (0..robot_chain_len) |i| {
            const cache_by_positions = if (i > 0) cache_by_positions_dpad_ptr else cache_by_positions_numpad_ptr;
            const robot_ptr = try allocator.create(Robot);
            robot_ptr.* = try Robot.init(allocator, target, cache_by_positions);

            try robot_chain_ptr.append(robot_ptr);

            target = robot_ptr.asTarget();
        }

        return Setup{
            .door = door_ptr,
            .robot_chain = robot_chain_ptr,
            .cache_by_positions_numpad = cache_by_positions_numpad_ptr,
            .cache_by_positions_dpad = cache_by_positions_dpad_ptr,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Setup) void {
        self.door.deinit();
        for (self.robot_chain.items) |robot_ptr| {
            robot_ptr.deinit();
            self.allocator.destroy(robot_ptr);
        }
        self.robot_chain.deinit();

        var iterator = self.cache_by_positions_numpad.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }

        iterator = self.cache_by_positions_dpad.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }

        self.cache_by_positions_numpad.deinit();
        self.cache_by_positions_dpad.deinit();
        self.allocator.destroy(self.cache_by_positions_numpad);
        self.allocator.destroy(self.cache_by_positions_dpad);
        self.allocator.destroy(self.door);
        self.allocator.destroy(self.robot_chain);
    }

    fn complexity(self: *Setup, codes: []const u8) !u64 {
        var result: u64 = 0;
        var line_tokenizer = std.mem.tokenizeScalar(u8, codes, '\n');
        var byte_list = ByteList.init(self.allocator);
        defer byte_list.deinit();
        const last_robot: *Robot = self.robot_chain.items[self.robot_chain.items.len - 1];
        const first_robot: *Robot = self.robot_chain.items[0];
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        while (line_tokenizer.next()) |moves| {
            var from: u8 = 'A';
            for (moves) |move| {
                const mtp = try last_robot.movesToPerform(allocator, move, from);
                var tokenizer = std.mem.tokenizeScalar(u8, mtp, '\n');
                const first_move = tokenizer.next().?;
                try byte_list.appendSlice(first_move);

                first_robot.cur_pos = NUMPAD.pos_of(move);
                from = move;
                _ = arena.reset(.retain_capacity);
            }
            const len: u64 = @intCast(byte_list.items.len);
            const code_num = try std.fmt.parseInt(u64, moves[0 .. moves.len - 1], 10);

            result += len * code_num;
            byte_list.clearRetainingCapacity();
        }

        return result;
    }
};

const INPUT = @embedFile("inputs/day21.txt");

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    var setup = try Setup.init(allocator, 13);
    const complexity = try setup.complexity(INPUT);

    std.debug.print("Complexity: {d}\n", .{complexity});
}

test "main input complexity for 3 robots in between" {
    var setup = try Setup.init(std.testing.allocator, 3);
    defer setup.deinit();
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

    const allocator = std.testing.allocator;

    var setup = try Setup.init(allocator, 3);
    defer setup.deinit();
    const complexity = try setup.complexity(codes);

    try std.testing.expectEqual(126384, complexity);
}
