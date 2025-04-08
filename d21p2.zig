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

const CacheByMovesOnTarget = std.StringHashMap([]const u8);
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
    performed: *ByteList,
    cache_by_positions: *CacheByPositions,
    cache_by_moves_on_target: *CacheByMovesOnTarget,
    moves_cache: *MovesCache,
    allocator: Allocator,

    fn init(allocator: Allocator, target: Target, cache_by_positions: *CacheByPositions) !Self {
        const list_ptr = try allocator.create(ByteList);
        list_ptr.* = ByteList.init(allocator);
        const moves_cache_ptr = try allocator.create(MovesCache);
        moves_cache_ptr.* = MovesCache.init(allocator);
        const cache_by_moves_on_target_ptr = try allocator.create(CacheByMovesOnTarget);
        cache_by_moves_on_target_ptr.* = CacheByMovesOnTarget.init(allocator);
        return Self{ .target = target, .performed = list_ptr, .cache_by_positions = cache_by_positions, .cache_by_moves_on_target = cache_by_moves_on_target_ptr, .moves_cache = moves_cache_ptr, .allocator = allocator };
    }

    fn deinit(self: *Robot) void {
        self.performed.deinit();
        self.allocator.destroy(self.performed);

        var iterator = self.cache_by_moves_on_target.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }

        var moves_cache_iterator = self.moves_cache.iterator();
        while (moves_cache_iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }

        self.moves_cache.deinit();
        self.allocator.destroy(self.moves_cache);

        self.cache_by_moves_on_target.deinit();
        self.allocator.destroy(self.cache_by_moves_on_target);
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
        const panic = DPAD.pos_of(' ');
        var cur = begin;
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

        if (out.items.len == 0) {
            cur = begin;
            if ((cur.row != panic.row or dest.col != panic.col)) {
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

    fn movesToPerformOnMe(self: *Self, allocator: Allocator, moves_on_target: []const u8) []const u8 {
        const key = self.allocator.dupe(u8, moves_on_target) catch unreachable;
        if (self.cache_by_moves_on_target.get(key)) |value| {
            self.allocator.free(key);
            return value;
        }

        var out = ByteList.init(allocator);

        var from_pos = DPAD.pos_of('A');
        for (moves_on_target) |move| {
            const dest_pos = DPAD.pos_of(move);
            out.appendSlice(self.movesByPositions(allocator, dest_pos, from_pos) catch unreachable) catch unreachable;

            from_pos = dest_pos;
        }

        const result = out.items;
        self.cache_by_moves_on_target.put(key, self.allocator.dupe(u8, result) catch unreachable) catch unreachable;
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
            if (moves_set_to_perform_on_me.len < min_len) {
                out.clearRetainingCapacity();

                try out.appendSlice(moves_set_to_perform_on_me);
                min_len = moves_set_to_perform_on_me.len;
            } else if (moves_set_to_perform_on_me.len == min_len) {
                if (out.items.len != 0) {
                    try out.append('\n');
                }
                try out.appendSlice(moves_set_to_perform_on_me);
            }
        }

        const result = out.items;
        // std.debug.print("{c}-{c}: {s}\n", .{ from, dest, result });
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
    cache_by_positions: *CacheByPositions,
    allocator: Allocator,

    fn init(allocator: Allocator, cache_by_positions: *CacheByPositions) !Door {
        const list_ptr = try allocator.create(ByteList);
        list_ptr.* = ByteList.init(allocator);
        return Door{ .performed = list_ptr, .cache_by_positions = cache_by_positions, .allocator = allocator };
    }

    fn deinit(self: *Door) void {
        self.performed.deinit();
        self.allocator.destroy(self.performed);
    }

    fn movesByPositions(self: *Door, allocator: Allocator, dest: Position, begin: Position) ![]const u8 {
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
        const panic = NUMPAD.pos_of(' ');
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
        // std.debug.print("movesByPositions(dest: {d},{d} , from: {d},{d}) = {s}\n", .{ dest.col, dest.row, begin.col, begin.row, out.items });
        const result = out.items;
        try self.cache_by_positions.put(key, try self.allocator.dupe(u8, result));
        return result;
    }

    fn movesToPerform(self: *Door, allocator: Allocator, dest: u8, from: u8) ![]const u8 {
        const dest_pos = NUMPAD.pos_of(dest);
        const from_pos = NUMPAD.pos_of(from);

        const result = try self.movesByPositions(allocator, dest_pos, from_pos);
        // std.debug.print("{c}-{c}: {s}\n", .{ from, dest, result });
        return result;
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
        const cache_by_positions_numpad_ptr = try allocator.create(CacheByPositions);
        cache_by_positions_numpad_ptr.* = CacheByPositions.init(allocator);

        const door_ptr = try allocator.create(Door);
        door_ptr.* = try Door.init(allocator, cache_by_positions_numpad_ptr);

        const cache_by_positions_dpad_ptr = try allocator.create(CacheByPositions);
        cache_by_positions_dpad_ptr.* = CacheByPositions.init(allocator);

        const robot_chain_ptr = try allocator.create(RobotChain);
        robot_chain_ptr.* = try RobotChain.initCapacity(allocator, robot_chain_len);

        var target = door_ptr.asTarget();
        for (0..robot_chain_len) |_| {
            const robot_ptr = try allocator.create(Robot);
            robot_ptr.* = try Robot.init(allocator, target, cache_by_positions_dpad_ptr);

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
        const last_robot: *Robot = self.robot_chain.items[self.robot_chain.items.len - 1];
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        while (line_tokenizer.next()) |moves| {
            var from: u8 = 'A';
            var cost: u64 = 0;
            for (moves) |move| {
                const mtp = try last_robot.movesToPerform(allocator, move, from);
                var tokenizer = std.mem.tokenizeScalar(u8, mtp, '\n');
                if (tokenizer.next()) |first_move| {
                    cost += first_move.len;
                } else {
                    unreachable;
                }

                from = move;
                _ = arena.reset(.retain_capacity);
            }
            const len: u64 = cost;
            const code_num = try std.fmt.parseInt(u64, moves[0 .. moves.len - 1], 10);

            result += len * code_num;
        }

        return result;
    }
};

const INPUT = @embedFile("inputs/day21.txt");

pub fn main() !void {
    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    var setup = try Setup.init(allocator, 16);
    const complexity = try setup.complexity(INPUT);

    std.debug.print("Complexity: {d}\n", .{complexity});
}

test "main input complexity for 3 robots in between" {
    var setup = try Setup.init(std.testing.allocator, 2);
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

    var setup = try Setup.init(allocator, 2);
    defer setup.deinit();
    const complexity = try setup.complexity(codes);

    try std.testing.expectEqual(126384, complexity);
}
