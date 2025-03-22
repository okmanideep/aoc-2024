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

fn contains(items: []Position, value: Position) bool {
    for (items) |item| {
        if (std.meta.eql(value, item)) return true;
    }

    return false;
}

fn findTrailends(out: *ArrayList(Position), grid: Grid, start: Position) !void {
    if (grid.atP(start) == '9') {
        if (!contains(out.items, start)) {
            try out.append(start);
        }
        return;
    }

    if (start.row > 0) {
        // can go up
        if (grid.atP(start) < grid.at(start.col, start.row - 1) and grid.at(start.col, start.row - 1) - grid.atP(start) == 1) {
            try findTrailends(out, grid, Position{ .col = start.col, .row = start.row - 1 });
        }
    }

    if (start.col < grid.size - 1) {
        // can go right
        if (grid.atP(start) < grid.at(start.col + 1, start.row) and grid.at(start.col + 1, start.row) - grid.atP(start) == 1) {
            try findTrailends(out, grid, Position{ .col = start.col + 1, .row = start.row });
        }
    }

    if (start.row < grid.size - 1) {
        // can go down
        if (grid.atP(start) < grid.at(start.col, start.row + 1) and grid.at(start.col, start.row + 1) - grid.atP(start) == 1) {
            try findTrailends(out, grid, Position{ .col = start.col, .row = start.row + 1 });
        }
    }

    if (start.col > 0) {
        // can go left
        if (grid.atP(start) < grid.at(start.col - 1, start.row) and grid.at(start.col - 1, start.row) - grid.atP(start) == 1) {
            try findTrailends(out, grid, Position{ .col = start.col - 1, .row = start.row });
        }
    }
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
    var trailends = ArrayList(Position).init(allocator);
    defer trailends.deinit();
    for (trailheads.items) |trailhead| {
        try findTrailends(&trailends, grid, trailhead);
        score += trailends.items.len;

        trailends.clearRetainingCapacity();
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
    var trailends = ArrayList(Position).init(allocator);
    defer trailends.deinit();
    for (trailheads.items) |trailhead| {
        try findTrailends(&trailends, grid, trailhead);
        score += trailends.items.len;

        trailends.clearRetainingCapacity();
    }

    try std.testing.expectEqual(36, score);
}
