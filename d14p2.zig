const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const INPUT = @embedFile("inputs/day14.txt");

const GridError = error{InvalidSize};

const Grid = struct {
    size_x: usize,
    size_y: usize,
    counts: []usize,
    allocator: Allocator,

    fn init(allocator: Allocator, size_x: usize, size_y: usize) !Grid {
        if (size_x % 2 == 0 or size_y % 2 == 0) return GridError.InvalidSize;

        const counts = try allocator.alloc(usize, size_x * size_y);
        @memset(counts, 0);
        return Grid{ .size_x = size_x, .size_y = size_y, .counts = counts, .allocator = allocator };
    }

    fn deinit(self: Grid) void {
        self.allocator.free(self.counts);
    }

    fn increment(self: Grid, x: usize, y: usize) void {
        const index = y * self.size_x + x;
        self.counts[index] += 1;
    }

    fn clear(self: Grid) void {
        @memset(self.counts, 0);
    }

    fn at(self: Grid, x: usize, y: usize) usize {
        const index = y * self.size_x + x;
        return self.counts[index];
    }

    fn isChristmasTree(self: Grid) bool {
        var y: usize = 0;
        while (y < self.size_y) : (y += 1) {
            var first_non_zero_index: usize = self.size_x + 1;
            var non_zeros_ended: bool = false;
            var x: usize = 0;
            x_axis: while (x < self.size_x) : (x += 1) {
                if (first_non_zero_index > self.size_x) {
                    if (self.at(x, y) == 0) {
                        continue :x_axis;
                    } else {
                        first_non_zero_index = x;
                    }
                } else if (!non_zeros_ended) {
                    if (self.at(x, y) == 0) {
                        non_zeros_ended = true;
                        if (x - first_non_zero_index > 10) {
                            return true;
                        }
                    } else {
                        continue :x_axis;
                    }
                } else {
                    if (self.at(x, y) == 0) {
                        first_non_zero_index = self.size_x + 1;
                        non_zeros_ended = false;
                        continue :x_axis;
                    }
                }
            }
        }

        return false;
    }

    fn print(self: Grid) !void {
        const stdout = std.io.getStdOut().writer();
        var y: usize = 0;
        while (y < self.size_y) : (y += 1) {
            var x: usize = 0;
            while (x < self.size_x) : (x += 1) {
                const count = self.at(x, y);
                const char: u8 = if (count == 0) '.' else if (count < 10) ('0' + @as(u8, @intCast(count))) else '*';
                try stdout.print("{c}", .{char});
            }
            try stdout.print("\n", .{});
        }
    }

    fn safetyFactor(self: Grid) usize {
        var q1: usize = 0;
        var q2: usize = 0;
        var q3: usize = 0;
        var q4: usize = 0;

        var y: usize = 0;

        while (y < self.size_y / 2) : (y += 1) {
            var x: usize = 0;
            while (x < self.size_x / 2) : (x += 1) {
                q1 += self.at(x, y);
            }
        }

        y = 0;
        while (y < self.size_y / 2) : (y += 1) {
            var x: usize = (self.size_x / 2) + 1;
            while (x < self.size_x) : (x += 1) {
                q2 += self.at(x, y);
            }
        }

        y = (self.size_y / 2) + 1;
        while (y < self.size_y) : (y += 1) {
            var x: usize = 0;
            while (x < self.size_x / 2) : (x += 1) {
                q3 += self.at(x, y);
            }
        }

        y = (self.size_y / 2) + 1;
        while (y < self.size_y) : (y += 1) {
            var x: usize = (self.size_x / 2) + 1;
            while (x < self.size_x) : (x += 1) {
                q4 += self.at(x, y);
            }
        }

        return q1 * q2 * q3 * q4;
    }
};

const Position = struct {
    x: usize,
    y: usize,
};

const Robot = struct {
    // initial position
    px: usize,
    py: usize,

    // velocity
    vx: isize,
    vy: isize,

    fn parse(line: []const u8) !Robot {
        var tokenizer = std.mem.tokenizeAny(u8, line, "pv,= \n\r");

        const px = try std.fmt.parseInt(usize, tokenizer.next() orelse unreachable, 10);
        const py = try std.fmt.parseInt(usize, tokenizer.next() orelse unreachable, 10);
        const vx = try std.fmt.parseInt(isize, tokenizer.next() orelse unreachable, 10);
        const vy = try std.fmt.parseInt(isize, tokenizer.next() orelse unreachable, 10);

        return Robot{ .px = px, .py = py, .vx = vx, .vy = vy };
    }

    fn positionAfter(self: Robot, count: isize, size_x: usize, size_y: usize) Position {
        const final_x_signed = @mod((@as(isize, @intCast(self.px)) + count * self.vx), @as(isize, @intCast(size_x)));
        const final_y_signed = @mod((@as(isize, @intCast(self.py)) + count * self.vy), @as(isize, @intCast(size_y)));

        const final_x: usize = @intCast(final_x_signed);
        const final_y: usize = @intCast(final_y_signed);
        return Position{ .x = final_x, .y = final_y };
    }
};

pub fn main() !void {
    const size_x = 101;
    const size_y = 103;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    const grid = try Grid.init(allocator, size_x, size_y);
    defer grid.deinit();

    var robot_list = try ArrayList(Robot).initCapacity(allocator, 500);
    defer robot_list.deinit();

    var linesTokenizer = std.mem.tokenizeScalar(u8, INPUT, '\n');
    while (linesTokenizer.next()) |line| {
        const robot = try Robot.parse(line);
        try robot_list.append(robot);
        grid.increment(robot.px, robot.py);
    }

    var count: isize = 0;

    const stdout = std.io.getStdOut().writer();

    while (true) {
        count += 1;

        grid.clear();
        for (robot_list.items) |robot| {
            const pos = robot.positionAfter(count, size_x, size_y);
            grid.increment(pos.x, pos.y);
        }

        if (grid.isChristmasTree()) {
            try stdout.print("COUNT: {d}\n", .{count});
            try grid.print();
            break;
        } else if (@mod(count, 100_000) == 0) {
            try stdout.print("Failed upto {d}\n", .{count});
        }
    }
}

test "Robot.parse" {
    const line =
        \\p=62,65 v=-96,-93
    ;

    const robot = try Robot.parse(line);
    try std.testing.expect(robot.px == 62);
    try std.testing.expect(robot.py == 65);
    try std.testing.expect(robot.vx == -96);
    try std.testing.expect(robot.vy == -93);
}

test "aoc example" {
    const input =
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
        \\p=10,3 v=-1,2
        \\p=2,0 v=2,-1
        \\p=0,0 v=1,3
        \\p=3,0 v=-2,-2
        \\p=7,6 v=-1,-3
        \\p=3,0 v=-1,-2
        \\p=9,3 v=2,3
        \\p=7,3 v=-1,2
        \\p=2,4 v=2,-3
        \\p=9,5 v=-3,-3
    ;

    const size_x = 11;
    const size_y = 7;
    const allocator = std.testing.allocator;
    const grid = try Grid.init(allocator, size_x, size_y);
    defer grid.deinit();

    var linesTokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (linesTokenizer.next()) |line| {
        const robot = try Robot.parse(line);
        const final_pos = robot.positionAfter(100, size_x, size_y);
        grid.increment(final_pos.x, final_pos.y);
    }

    try std.testing.expectEqual(12, grid.safetyFactor());
}
