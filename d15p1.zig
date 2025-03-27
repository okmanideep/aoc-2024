const std = @import("std");
const INPUT = @embedFile("inputs/day15.txt");

const SMALL_EXAMPLE =
    \\########
    \\#..O.O.#
    \\##@.O..#
    \\#...O..#
    \\#.#.O..#
    \\#...O..#
    \\#......#
    \\########
    \\
    \\<^^>>>vv<v>>v<<
;

const Grid = struct {
    size: usize,
    bytes: []u8,
    cur_x: usize,
    cur_y: usize,

    fn init(bytes: []u8, size: usize) Grid {
        var y: usize = 0;
        var x: usize = 0;
        find_pos: while (y < size) : (y += 1) {
            x = 0;
            while (x < size) : (x += 1) {
                const index = y * (size + 1) + x;
                if (bytes[index] == '@') {
                    bytes[index] = '.';
                    break :find_pos;
                }
            }
        }

        return Grid{ .bytes = bytes, .size = size, .cur_x = x, .cur_y = y };
    }

    fn at(self: *Grid, x: usize, y: usize) u8 {
        const index = y * (self.size + 1) + x;
        return self.bytes[index];
    }

    fn print(self: *Grid) !void {
        const stdout = std.io.getStdOut().writer();
        var y: usize = 0;
        while (y < self.size) : (y += 1) {
            var x: usize = 0;
            while (x < self.size) : (x += 1) {
                try stdout.print("{c}", .{self.at(x, y)});
            }
            try stdout.print("\n", .{});
        }
    }

    fn setAt(self: *Grid, value: u8, x: usize, y: usize) void {
        const index = y * (self.size + 1) + x;
        self.bytes[index] = value;
    }

    fn sumOfGPSOfBoxes(self: *Grid) usize {
        var sum: usize = 0;
        var y: usize = 0;
        while (y < self.size) : (y += 1) {
            var x: usize = 0;
            while (x < self.size) : (x += 1) {
                const value = self.at(x, y);
                if (value == 'O') {
                    sum += y * 100 + x;
                }
            }
        }

        return sum;
    }

    fn executeAll(self: *Grid, movements: []const u8) void {
        for (movements) |movement| {
            self.execute(movement);
        }
    }

    fn execute(self: *Grid, movement: u8) void {
        switch (movement) {
            '<' => self.executeLeft(),
            '>' => self.executeRight(),
            '^' => self.executeUp(),
            'v' => self.executeDown(),
            '\n' => {},
            else => unreachable,
        }
    }

    fn executeLeft(self: *Grid) void {
        const end_x = self.cur_x;
        var start_x = end_x;
        var can_move = false;
        while (start_x > 0) : (start_x -= 1) {
            if (self.at(start_x - 1, self.cur_y) == '.') {
                can_move = true;
                break;
            } else if (self.at(start_x - 1, self.cur_y) == '#') {
                break;
            }
        }

        if (!can_move) return;
        for (start_x..end_x) |x| {
            const temp = self.at(x, self.cur_y);
            self.setAt(self.at(x - 1, self.cur_y), x, self.cur_y);
            self.setAt(temp, x - 1, self.cur_y);
        }
        self.cur_x = self.cur_x - 1;
    }

    fn executeRight(self: *Grid) void {
        const start_x = self.cur_x;
        var end_x = start_x;
        var can_move = false;
        while (end_x < self.size - 1) : (end_x += 1) {
            if (self.at(end_x + 1, self.cur_y) == '.') {
                can_move = true;
                break;
            } else if (self.at(end_x + 1, self.cur_y) == '#') {
                break;
            }
        }

        if (!can_move) return;
        var x = end_x;
        while (x >= start_x) : (x -= 1) {
            const temp = self.at(x, self.cur_y);
            self.setAt(self.at(x + 1, self.cur_y), x, self.cur_y);
            self.setAt(temp, x + 1, self.cur_y);
        }
        self.cur_x = self.cur_x + 1;
    }

    fn executeUp(self: *Grid) void {
        const end_y = self.cur_y;
        var start_y = end_y;
        var can_move = false;
        while (start_y > 0) : (start_y -= 1) {
            if (self.at(self.cur_x, start_y - 1) == '.') {
                can_move = true;
                break;
            } else if (self.at(self.cur_x, start_y - 1) == '#') {
                break;
            }
        }

        if (!can_move) return;
        for (start_y..end_y) |y| {
            const temp = self.at(self.cur_x, y);
            self.setAt(self.at(self.cur_x, y - 1), self.cur_x, y);
            self.setAt(temp, self.cur_x, y - 1);
        }
        self.cur_y = self.cur_y - 1;
    }

    fn executeDown(self: *Grid) void {
        const start_y = self.cur_y;
        var end_y = start_y;
        var can_move = false;
        while (end_y < self.size - 1) : (end_y += 1) {
            if (self.at(self.cur_x, end_y + 1) == '.') {
                can_move = true;
                break;
            } else if (self.at(self.cur_x, end_y + 1) == '#') {
                break;
            }
        }

        if (!can_move) return;
        var y = end_y;
        while (y >= start_y) : (y -= 1) {
            const temp = self.at(self.cur_x, y);
            self.setAt(self.at(self.cur_x, y + 1), self.cur_x, y);
            self.setAt(temp, self.cur_x, y + 1);
        }
        self.cur_y = self.cur_y + 1;
    }
};

fn findEndOfGrid(input: []const u8) usize {
    var index: usize = 0;
    while (index < input.len - 1) : (index += 1) {
        if (input[index] == '\n' and input[index + 1] == '\n') return index;
    }

    return input.len;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY_LEAK");
    }

    const grid_end_pos = findEndOfGrid(INPUT);
    if (grid_end_pos >= INPUT.len) unreachable;

    var bytes = try allocator.alloc(u8, grid_end_pos);
    defer allocator.free(bytes);
    @memcpy(bytes, INPUT[0..grid_end_pos]);

    var grid = Grid.init(bytes[0..], 50);
    grid.executeAll(INPUT[grid_end_pos + 1 ..]);

    try std.io.getStdOut().writer().print("Result: {d}\n", .{grid.sumOfGPSOfBoxes()});
}

test "small example step by step" {
    const allocator = std.testing.allocator;

    const grid_end_pos = findEndOfGrid(SMALL_EXAMPLE);
    if (grid_end_pos >= SMALL_EXAMPLE.len) unreachable;

    const initial_state =
        \\########
        \\#..O.O.#
        \\##@.O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
    ;
    var bytes: []u8 = try allocator.alloc(u8, initial_state.len);
    defer allocator.free(bytes);
    @memcpy(bytes, initial_state);
    var grid = Grid.init(bytes[0..], 8);
    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left_1 =
        \\########
        \\#..O.O.#
        \\##@.O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left_1, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('^');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_up_1 =
        \\########
        \\#.@O.O.#
        \\##..O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_up_1, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('^');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_up_2 = expected_after_up_1;
    try std.testing.expectEqualSlices(u8, expected_after_up_2, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('>');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_right_1 =
        \\########
        \\#..@OO.#
        \\##..O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_right_1, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('>');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_right_2 =
        \\########
        \\#...@OO#
        \\##..O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_right_2, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('v');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_down_1 =
        \\########
        \\#....OO#
        \\##..@..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#...O..#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_down_1, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('v');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_down_2 = expected_after_down_1;
    try std.testing.expectEqualSlices(u8, expected_after_down_2, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left_2 =
        \\########
        \\#....OO#
        \\##.@...#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#...O..#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left_2, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('v');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_down_3 =
        \\########
        \\#....OO#
        \\##.....#
        \\#..@O..#
        \\#.#.O..#
        \\#...O..#
        \\#...O..#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_down_3, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('>');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_right_3 =
        \\########
        \\#....OO#
        \\##.....#
        \\#...@O.#
        \\#.#.O..#
        \\#...O..#
        \\#...O..#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_right_3, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('>');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_right_4 =
        \\########
        \\#....OO#
        \\##.....#
        \\#....@O#
        \\#.#.O..#
        \\#...O..#
        \\#...O..#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_right_4, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('v');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_down_4 =
        \\########
        \\#....OO#
        \\##.....#
        \\#.....O#
        \\#.#.O@.#
        \\#...O..#
        \\#...O..#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_down_4, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left_3 =
        \\########
        \\#....OO#
        \\##.....#
        \\#.....O#
        \\#.#O@..#
        \\#...O..#
        \\#...O..#
        \\########
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left_3, grid.bytes);
}

test "small example full" {
    const final_grid =
        \\########
        \\#....OO#
        \\##.....#
        \\#.....O#
        \\#.#O@..#
        \\#...O..#
        \\#...O..#
        \\########
    ;

    const allocator = std.testing.allocator;

    const grid_end_pos = findEndOfGrid(SMALL_EXAMPLE);
    if (grid_end_pos >= SMALL_EXAMPLE.len) unreachable;

    var bytes = try allocator.alloc(u8, grid_end_pos);
    defer allocator.free(bytes);
    @memcpy(bytes, SMALL_EXAMPLE[0..grid_end_pos]);

    var grid = Grid.init(bytes[0..], 8);
    grid.executeAll(SMALL_EXAMPLE[grid_end_pos + 1 ..]);

    grid.setAt('@', grid.cur_x, grid.cur_y);

    try std.testing.expectEqualSlices(u8, final_grid, grid.bytes);
    try std.testing.expectEqual(2028, grid.sumOfGPSOfBoxes());
}

test "BIGGER EXAMPLE" {
    const bigger_example =
        \\##########
        \\#..O..O.O#
        \\#......O.#
        \\#.OO..O.O#
        \\#..O@..O.#
        \\#O#..O...#
        \\#O..O..O.#
        \\#.OO.O.OO#
        \\#....O...#
        \\##########
        \\
        \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
        \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
        \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
        \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
        \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
        \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
        \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
        \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
        \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
        \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
    ;

    const grid_end_pos = findEndOfGrid(bigger_example);
    if (grid_end_pos >= bigger_example.len) unreachable;

    const allocator = std.testing.allocator;

    var bytes = try allocator.alloc(u8, grid_end_pos);
    defer allocator.free(bytes);
    @memcpy(bytes, bigger_example[0..grid_end_pos]);

    var grid = Grid.init(bytes[0..], 10);
    grid.executeAll(bigger_example[grid_end_pos + 1 ..]);
    grid.setAt('@', grid.cur_x, grid.cur_y);

    const final_grid =
        \\##########
        \\#.O.O.OOO#
        \\#........#
        \\#OO......#
        \\#OO@.....#
        \\#O#.....O#
        \\#O.....OO#
        \\#O.....OO#
        \\#OO....OO#
        \\##########
    ;
    try std.testing.expectEqualSlices(u8, final_grid, grid.bytes);

    try std.testing.expectEqual(10092, grid.sumOfGPSOfBoxes());
}
