const std = @import("std");
const ArrayList = std.ArrayList;
const INPUT = @embedFile("inputs/day10.txt");
const TEST_INPUT = @embedFile("inputs/day10-test.txt");

const Position = struct {
    col: u8,
    row: u8,
};

const Grid = struct {
    bytes: []const u8,
    size: u8,

    fn from(bytes: []const u8, size: u8) Grid {
        return Grid{ .bytes = bytes, .size = size };
    }

    fn at(self: Grid, col: u8, row: u8) u8 {
        return self.bytes[self.posFor(col, row)];
    }

    fn atP(self: Grid, pos: Position) u8 {
        return self.at(pos.col, pos.row);
    }

    fn posFor(self: Grid, col: u8, row: u8) usize {
        const pos: usize = @as(usize, @intCast(row)) * (self.size + 1) + col;
        return pos;
    }
};

fn findTrailheads(out: *ArrayList(Position), grid: Grid) !void {
    var row: u8 = 0;
    while (row < grid.size) : (row += 1) {
        var col: u8 = 0;
        while (col < grid.size) : (col += 1) {
            if (grid.at(col, row) == '0') try out.append(Position{ .col = col, .row = row });
        }
    }
}

fn calculateTrailscore(grid: Grid, start: Position, current_score: usize) !usize {
    if (grid.atP(start) == '9') {
        return current_score + 1;
    }

    var score: usize = current_score;
    if (start.row > 0) {
        // can go up
        if (grid.atP(start) < grid.at(start.col, start.row - 1) and grid.at(start.col, start.row - 1) - grid.atP(start) == 1) {
            score = try calculateTrailscore(grid, Position{ .col = start.col, .row = start.row - 1 }, score);
        }
    }

    if (start.col < grid.size - 1) {
        // can go right
        if (grid.atP(start) < grid.at(start.col + 1, start.row) and grid.at(start.col + 1, start.row) - grid.atP(start) == 1) {
            score = try calculateTrailscore(grid, Position{ .col = start.col + 1, .row = start.row }, score);
        }
    }

    if (start.row < grid.size - 1) {
        // can go down
        if (grid.atP(start) < grid.at(start.col, start.row + 1) and grid.at(start.col, start.row + 1) - grid.atP(start) == 1) {
            score = try calculateTrailscore(grid, Position{ .col = start.col, .row = start.row + 1 }, score);
        }
    }

    if (start.col > 0) {
        // can go left
        if (grid.atP(start) < grid.at(start.col - 1, start.row) and grid.at(start.col - 1, start.row) - grid.atP(start) == 1) {
            score = try calculateTrailscore(grid, Position{ .col = start.col - 1, .row = start.row }, score);
        }
    }

    return score;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    const grid = Grid.from(INPUT, 59);
    var trailheads = ArrayList(Position).init(allocator);
    defer trailheads.deinit();

    try findTrailheads(&trailheads, grid);

    var score: usize = 0;
    for (trailheads.items) |trailhead| {
        score = try calculateTrailscore(grid, trailhead, score);
    }

    try std.io.getStdOut().writer().print("Result: {}\n", .{score});
}

test "aoc example" {
    const allocator = std.testing.allocator;

    const grid = Grid.from(TEST_INPUT[0..], 8);
    try std.testing.expectEqual('8', grid.at(0, 0));
    try std.testing.expectEqual('7', grid.at(0, 1));
    try std.testing.expectEqual('2', grid.at(7, 7));

    var trailheads = ArrayList(Position).init(allocator);
    defer trailheads.deinit();
    try findTrailheads(&trailheads, grid);

    try std.testing.expectEqual(9, trailheads.items.len);

    var score: usize = 0;
    for (trailheads.items) |trailhead| {
        score = try calculateTrailscore(grid, trailhead, score);
    }

    try std.testing.expectEqual(81, score);
}
