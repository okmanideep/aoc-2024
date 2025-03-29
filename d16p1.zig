const std = @import("std");
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const INPUT = @embedFile("inputs/day16.txt");

const Direction = enum {
    right,
    left,
    up,
    down,

    fn asChar(self: Direction) u8 {
        return switch (self) {
            .right => '>',
            .left => '<',
            .up => '^',
            .down => 'v',
        };
    }

    fn clockwise(self: Direction) Direction {
        return switch (self) {
            .right => .down,
            .left => .up,
            .up => .right,
            .down => .left,
        };
    }

    fn antiClockwise(self: Direction) Direction {
        return switch (self) {
            .right => .up,
            .left => .down,
            .up => .left,
            .down => .right,
        };
    }
};

const Position = struct {
    col: usize,
    row: usize,
    fn ahead(self: Position, dir: Direction) Position {
        const row = switch (dir) {
            .right => self.row,
            .left => self.row,
            .up => self.row - 1,
            .down => self.row + 1,
        };

        const col = switch (dir) {
            .right => self.col + 1,
            .left => self.col - 1,
            .up => self.col,
            .down => self.col,
        };

        return .{ .col = col, .row = row };
    }
};

const Grid = struct {
    bytes: []u8,
    size: usize,
    allocator: Allocator,

    fn init(allocator: Allocator, input: []const u8, size: usize) !Grid {
        var bytes = try allocator.alloc(u8, input.len);
        @memcpy(bytes, input);
        return Grid{ .bytes = bytes[0..], .size = size, .allocator = allocator };
    }

    fn deinit(self: *Grid) void {
        self.allocator.free(self.bytes);
    }

    fn at(self: *Grid, pos: Position) u8 {
        const index = pos.row * (self.size + 1) + pos.col;
        return self.bytes[index];
    }

    fn markVisited(self: *Grid, pos: Position, direction: Direction) void {
        const index = pos.row * (self.size + 1) + pos.col;
        const char = direction.asChar();
        self.bytes[index] = char;
    }

    fn print(self: *Grid) !void {
        var writer = std.io.getStdOut().writer();
        try writer.writeAll(self.bytes);
    }
};

const Node = struct {
    pos: Position,
    dir: Direction,
    parent: ?*Node,
    ahead: ?*Node,
    cw: ?*Node,
    acw: ?*Node,
    score: u64,

    fn init(pos: Position, dir: Direction, parent: ?*Node) Node {
        return Node{ .pos = pos, .dir = dir, .parent = parent, .ahead = null, .cw = null, .acw = null, .score = std.math.maxInt(u64) };
    }

    fn destroy(self: *Node, allocator: Allocator) void {
        if (self.acw) |acw| acw.destroy(allocator);
        if (self.cw) |cw| cw.destroy(allocator);
        if (self.ahead) |ahead| ahead.destroy(allocator);
        allocator.destroy(self);
    }

    fn isDeadEnd(self: *Node) bool {
        return self.ahead == null and self.cw == null and self.acw == null;
    }

    fn hasVisited(self: *Node, pos: Position) bool {
        var result = false;
        if (std.meta.eql(self.pos, pos)) {
            result = true;
        } else {
            if (self.parent) |parent| {
                result = parent.hasVisited(pos);
            } else {
                result = false;
            }
        }
        return result;
    }
};

fn buildTree(allocator: Allocator, grid: *Grid, pos: Position, dir: Direction, parent: ?*Node) !?*Node {
    var node_ptr = try allocator.create(Node);
    node_ptr.* = Node.init(pos, dir, parent);

    if (grid.at(pos) == 'E') {
        node_ptr.score = 0;
        return node_ptr; // no need to go any where else;
    }

    const ahead = pos.ahead(dir);
    if (grid.at(ahead) != '#' and !node_ptr.hasVisited(ahead)) {
        node_ptr.ahead = try buildTree(allocator, grid, ahead, dir, node_ptr);
    }

    const cw = pos.ahead(dir.clockwise());
    if (grid.at(cw) != '#' and !node_ptr.hasVisited(cw)) {
        node_ptr.cw = try buildTree(allocator, grid, cw, dir.clockwise(), node_ptr);
    }

    const acw = pos.ahead(dir.antiClockwise());
    if (grid.at(acw) != '#' and !node_ptr.hasVisited(acw)) {
        node_ptr.acw = try buildTree(allocator, grid, acw, dir.antiClockwise(), node_ptr);
    }

    if (node_ptr.isDeadEnd()) {
        allocator.destroy(node_ptr);
        return null;
    }

    return node_ptr;
}

fn computeLeastScores(node: *Node) void {
    if (node.score == 0) return;

    const max = std.math.maxInt(u64);
    var score: u64 = max;

    if (node.ahead) |ahead| {
        computeLeastScores(ahead);

        if (ahead.score < max and ahead.score + 1 < score) {
            score = ahead.score + 1;
        }
    }

    if (node.cw) |cw| {
        computeLeastScores(cw);

        if (cw.score < max and cw.score + 1000 + 1 < score) {
            score = cw.score + 1000 + 1;
        }
    }

    if (node.acw) |acw| {
        computeLeastScores(acw);

        if (acw.score < max and acw.score + 1000 + 1 < score) {
            score = acw.score + 1000 + 1;
        }
    }

    node.score = @min(score, node.score);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    const size = 141;
    var grid = try Grid.init(allocator, INPUT, size);
    defer grid.deinit();
    var starting_pos_index: usize = 0;
    while (starting_pos_index < INPUT.len) : (starting_pos_index += 1) {
        if (INPUT[starting_pos_index] == 'S') break;
    }

    const starting_pos_row = starting_pos_index / (size + 1);
    const starting_pos_col = starting_pos_index % (size + 1);
    const starting_pos: Position = .{ .col = starting_pos_col, .row = starting_pos_row };

    const root_ptr = try buildTree(allocator, &grid, starting_pos, .right, null);
    defer root_ptr.?.destroy(allocator);
    try std.io.getStdOut().writer().print("Tree built\n", .{});

    computeLeastScores(root_ptr.?);

    try std.io.getStdOut().writer().print("Result: {}\n", .{root_ptr.?.score});
}

test "aoc first example" {
    const input =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
    ;

    const allocator = std.testing.allocator;
    const size = 15;
    var grid = try Grid.init(allocator, input, size);
    defer grid.deinit();
    var starting_pos_index: usize = 0;
    while (starting_pos_index < input.len) : (starting_pos_index += 1) {
        if (input[starting_pos_index] == 'S') break;
    }

    const starting_pos_row = starting_pos_index / (size + 1);
    const starting_pos_col = starting_pos_index % (size + 1);
    const starting_pos: Position = .{ .col = starting_pos_col, .row = starting_pos_row };

    const root_ptr = try buildTree(allocator, &grid, starting_pos, .right, null);
    defer root_ptr.?.destroy(allocator);

    computeLeastScores(root_ptr.?);

    try std.testing.expectEqual(7036, root_ptr.?.score);
}

test "aoc second example" {
    const input =
        \\#################
        \\#...#...#...#..E#
        \\#.#.#.#.#.#.#.#.#
        \\#.#.#.#...#...#.#
        \\#.#.#.#.###.#.#.#
        \\#...#.#.#.....#.#
        \\#.#.#.#.#.#####.#
        \\#.#...#.#.#.....#
        \\#.#.#####.#.###.#
        \\#.#.#.......#...#
        \\#.#.###.#####.###
        \\#.#.#...#.....#.#
        \\#.#.#.#####.###.#
        \\#.#.#.........#.#
        \\#.#.#.#########.#
        \\#S#.............#
        \\#################
    ;

    const allocator = std.testing.allocator;
    const size = 17;
    var grid = try Grid.init(allocator, input, size);
    defer grid.deinit();
    var starting_pos_index: usize = 0;
    while (starting_pos_index < input.len) : (starting_pos_index += 1) {
        if (input[starting_pos_index] == 'S') break;
    }

    const starting_pos_row = starting_pos_index / (size + 1);
    const starting_pos_col = starting_pos_index % (size + 1);
    const starting_pos: Position = .{ .col = starting_pos_col, .row = starting_pos_row };

    const root_ptr = try buildTree(allocator, &grid, starting_pos, .right, null);
    defer root_ptr.?.destroy(allocator);

    computeLeastScores(root_ptr.?);

    try std.testing.expectEqual(11048, root_ptr.?.score);
}
