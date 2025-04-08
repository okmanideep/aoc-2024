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

const CacheByMovesOnTarget = std.StringHashMap([]const u8);
const CacheKey = struct {
    dest: u8,
    from: u8,
};
const MovesCache = std.AutoHashMap(CacheKey, []const u8);
const CostCache = std.AutoHashMap(CacheKey, u64);

const Robot = struct {
    const Self = Robot;
    index: usize,
    controller: ?*Robot,
    moves_cache: *MovesCache,
    cost_cache: *CostCache,
    allocator: Allocator,

    fn init(allocator: Allocator, index: usize, controller: ?*Robot, moves_cache: *MovesCache) !Self {
        const cost_cache_ptr = try allocator.create(CostCache);
        cost_cache_ptr.* = CostCache.init(allocator);
        return Self{ .index = index, .controller = controller, .moves_cache = moves_cache, .cost_cache = cost_cache_ptr, .allocator = allocator };
    }

    fn deinit(self: *Robot) void {
        self.cost_cache.deinit();
        self.allocator.destroy(self.cost_cache);
    }

    fn moves(self: *Self, dest_key: u8, from_key: u8) ![]const u8 {
        const allocator = self.allocator;
        const key = CacheKey{ .from = from_key, .dest = dest_key };
        if (self.moves_cache.get(key)) |value| {
            return value;
        }
        const dest = DPAD.pos_of(dest_key);
        const from = DPAD.pos_of(from_key);
        const panic = DPAD.pos_of(' ');
        // std.debug.print("movesByPositions(dest: {d},{d} , from: {d},{d})\n", .{ dest.col, dest.row, begin.col, begin.row });
        var out = ByteList.init(allocator);
        defer out.deinit();
        if (dest.col == from.col and dest.row == from.row) {
            try out.append('A');
            const result = try allocator.dupe(u8, out.items);
            try self.moves_cache.put(key, result);
            return result;
        }
        const both_horizontal_and_vertical_required = from.row != dest.row and from.col != dest.col;
        var cur = from;
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

        cur = from;
        if (both_horizontal_and_vertical_required or out.items.len == 0) {
            if ((cur.row != panic.row or dest.col != panic.col)) {
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
        const result = try allocator.dupe(u8, out.items);
        try self.moves_cache.put(key, result);
        return result;
    }

    fn costToPerform(self: *Robot, dest: u8, from: u8) !u64 {
        const key = CacheKey{ .from = from, .dest = dest };
        if (self.cost_cache.get(key)) |value| {
            return value;
        }

        const moves_set_to_perform = try self.moves(dest, from);
        var tokenizer = std.mem.tokenizeScalar(u8, moves_set_to_perform, '\n');
        var best_cost: u64 = std.math.maxInt(u64);

        while (tokenizer.next()) |moves_to_perform| {
            if (self.controller) |controller| {
                var prev: u8 = 'A';
                var cost: u64 = 0;
                for (moves_to_perform) |move| {
                    cost += try controller.costToPerform(move, prev);
                    prev = move;
                }

                if (cost < best_cost) {
                    best_cost = cost;
                }
            } else {
                if (moves_to_perform.len < best_cost) {
                    best_cost = moves_to_perform.len;
                }
            }
        }

        try self.cost_cache.put(key, best_cost);
        return best_cost;
    }
};

const Door = struct {
    controller: *Robot,
    moves_cache: *MovesCache,
    cost_cache: *CostCache,
    allocator: Allocator,

    fn init(allocator: Allocator, controller: *Robot, moves_cache: *MovesCache) !Door {
        const cost_cache_ptr = try allocator.create(CostCache);
        cost_cache_ptr.* = CostCache.init(allocator);
        return Door{ .controller = controller, .moves_cache = moves_cache, .cost_cache = cost_cache_ptr, .allocator = allocator };
    }

    fn deinit(self: *Door) void {
        self.cost_cache.deinit();
        self.allocator.destroy(self.cost_cache);
    }

    fn moves(self: *Door, dest_key: u8, from_key: u8) ![]const u8 {
        const key = CacheKey{ .from = from_key, .dest = dest_key };
        if (self.moves_cache.get(key)) |value| {
            return value;
        }
        const allocator = self.allocator;
        const dest = NUMPAD.pos_of(dest_key);
        const from = NUMPAD.pos_of(from_key);
        const panic = NUMPAD.pos_of(' ');
        // std.debug.print("movesByPositions(dest: {d},{d} , from: {d},{d})\n", .{ dest.col, dest.row, begin.col, begin.row });
        var out = ByteList.init(allocator);
        defer out.deinit();
        if (dest.col == from.col and dest.row == from.row) {
            try out.append('A');
            const result = try self.allocator.dupe(u8, out.items);
            try self.moves_cache.put(key, result);
            return result;
        }
        var cur = from;
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

        cur = from;
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
        const result = try self.allocator.dupe(u8, out.items);
        try self.moves_cache.put(key, result);
        return result;
    }

    fn costToPerform(self: *Door, dest: u8, from: u8) !u64 {
        const key = CacheKey{ .from = from, .dest = dest };
        if (self.cost_cache.get(key)) |value| {
            return value;
        }

        const moves_set_to_perform = try self.moves(dest, from);
        var tokenizer = std.mem.tokenizeScalar(u8, moves_set_to_perform, '\n');
        var best_cost: u64 = std.math.maxInt(u64);
        const controller = self.controller;

        while (tokenizer.next()) |moves_to_perform| {
            var prev: u8 = 'A';
            var cost: u64 = 0;
            for (moves_to_perform) |move| {
                cost += try controller.costToPerform(move, prev);
                prev = move;
            }

            if (cost < best_cost) {
                best_cost = cost;
            }
        }

        try self.cost_cache.put(key, best_cost);
        return best_cost;
    }
};

const RobotChain = ArrayList(*Robot);

const Setup = struct {
    door: *Door,
    robot_chain: *RobotChain,
    moves_cache: *MovesCache,
    allocator: Allocator,

    fn init(allocator: Allocator, robot_chain_len: u8) !Setup {
        const moves_cache_ptr = try allocator.create(MovesCache);
        moves_cache_ptr.* = MovesCache.init(allocator);

        const robot_chain_ptr = try allocator.create(RobotChain);
        robot_chain_ptr.* = try RobotChain.initCapacity(allocator, robot_chain_len);

        var controller: ?*Robot = null;
        for (0..robot_chain_len) |i| {
            const robot_ptr = try allocator.create(Robot);
            robot_ptr.* = try Robot.init(allocator, i, controller, moves_cache_ptr);

            try robot_chain_ptr.append(robot_ptr);

            controller = robot_ptr;
        }

        const door_ptr = try allocator.create(Door);
        door_ptr.* = try Door.init(allocator, controller.?, moves_cache_ptr);

        return Setup{
            .door = door_ptr,
            .robot_chain = robot_chain_ptr,
            .moves_cache = moves_cache_ptr,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Setup) void {
        for (self.robot_chain.items) |robot_ptr| {
            robot_ptr.deinit();
            self.allocator.destroy(robot_ptr);
        }
        self.robot_chain.deinit();
        self.door.deinit();

        var iterator = self.moves_cache.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.moves_cache.deinit();

        self.allocator.destroy(self.moves_cache);
        self.allocator.destroy(self.door);
        self.allocator.destroy(self.robot_chain);
    }

    fn complexity(self: *Setup, codes: []const u8) !u64 {
        var result: u64 = 0;
        var line_tokenizer = std.mem.tokenizeScalar(u8, codes, '\n');

        while (line_tokenizer.next()) |moves| {
            var from: u8 = 'A';
            var cost: u64 = 0;
            for (moves) |move| {
                cost += try self.door.costToPerform(move, from);
                from = move;
            }
            const code_num = try std.fmt.parseInt(u64, moves[0 .. moves.len - 1], 10);

            result += cost * code_num;
        }

        return result;
    }
};

const INPUT = @embedFile("inputs/day21.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var setup = try Setup.init(allocator, 25);
    defer setup.deinit();

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
