const std = @import("std");
const ArrayList = std.ArrayList;
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

fn contains(list: []Position, pos: Position) bool {
    var result = false;
    for (list) |p| {
        if (std.meta.eql(p, pos)) {
            result = true;
            break;
        }
    }
    return result;
}

const ScoreCacheKey = struct {
    pos: Position,
    dir: Direction,
};

const ScoreCache = AutoHashMap(ScoreCacheKey, u64);

const MAX = std.math.maxInt(u64);
fn leastScore(grid: *Grid, pos: Position, dir: Direction, visited: *ArrayList(Position), cache: *ScoreCache) !u64 {
    const key = ScoreCacheKey{ .pos = pos, .dir = dir };
    if (cache.get(key)) |value| {
        return value;
    }

    if (grid.at(pos) == 'E') return 0;

    try visited.append(pos);

    var score: u64 = MAX;
    const ahead = pos.ahead(dir);
    if (grid.at(ahead) != '#' and !contains(visited.items, ahead)) {
        const ahead_score = try leastScore(grid, ahead, dir, visited, cache);
        if (ahead_score < MAX and ahead_score + 1 < score) {
            score = ahead_score + 1;
        }
    }

    const cw = pos.ahead(dir.clockwise());
    if (grid.at(cw) != '#' and !contains(visited.items, cw)) {
        const cw_score = try leastScore(grid, cw, dir.clockwise(), visited, cache);
        if (cw_score < MAX and cw_score + 1000 + 1 < score) {
            score = cw_score + 1000 + 1;
        }
    }

    const acw = pos.ahead(dir.antiClockwise());
    if (grid.at(acw) != '#' and !contains(visited.items, acw)) {
        const acw_score = try leastScore(grid, acw, dir.antiClockwise(), visited, cache);
        if (acw_score < MAX and acw_score + 1000 + 1 < score) {
            score = acw_score + 1000 + 1;
        }
    }

    _ = visited.pop();

    try cache.put(key, score);
    return score;
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

    var visited = ArrayList(Position).init(allocator);
    defer visited.deinit();

    var scoreCache = ScoreCache.init(allocator);
    defer scoreCache.deinit();

    const least_score = try leastScore(&grid, starting_pos, .right, &visited, &scoreCache);

    try std.io.getStdOut().writer().print("Result: {}\n", .{least_score});
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

    var visited = ArrayList(Position).init(allocator);
    defer visited.deinit();

    var scoreCache = ScoreCache.init(allocator);
    defer scoreCache.deinit();

    const least_score = try leastScore(&grid, starting_pos, .right, &visited, &scoreCache);

    try std.testing.expectEqual(7036, least_score);
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

    var visited = ArrayList(Position).init(allocator);
    defer visited.deinit();

    var scoreCache = ScoreCache.init(allocator);
    defer scoreCache.deinit();

    const least_score = try leastScore(&grid, starting_pos, .right, &visited, &scoreCache);

    try std.testing.expectEqual(11048, least_score);
}
