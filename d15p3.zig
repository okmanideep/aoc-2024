const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const posix = std.posix;
const builtin = @import("builtin");
const INPUT = @embedFile("inputs/day15.txt");

fn allMatch(bytes: []u8, value: u8) bool {
    for (bytes) |byte| {
        if (byte != value) {
            return false;
        }
    }

    return true;
}

fn contains(bytes: []u8, value: u8) bool {
    for (bytes) |byte| {
        if (byte == value) {
            return true;
        }
    }

    return false;
}

const Grid = struct {
    size: usize,
    bytes: []u8,
    cur_x: usize,
    cur_y: usize,
    allocator: Allocator,

    fn init(allocator: Allocator, bytes: []const u8, size: usize) !Grid {
        var new_bytes: []u8 = try allocator.alloc(u8, (2 * size + 1) * size - 1);
        @memset(new_bytes, 0);

        var y: usize = 0;
        var x: usize = 0;
        while (y < size) : (y += 1) {
            x = 0;
            while (x < size) : (x += 1) {
                const index = y * (size + 1) + x;
                const value = bytes[index];

                const new_index = (y * (size * 2 + 1)) + (2 * x);
                switch (value) {
                    '#' => {
                        new_bytes[new_index] = '#';
                        new_bytes[new_index + 1] = '#';
                    },
                    'O' => {
                        new_bytes[new_index] = '[';
                        new_bytes[new_index + 1] = ']';
                    },
                    '.' => {
                        new_bytes[new_index] = '.';
                        new_bytes[new_index + 1] = '.';
                    },
                    '@' => {
                        new_bytes[new_index] = '@';
                        new_bytes[new_index + 1] = '.';
                    },
                    else => unreachable,
                }
            }
            const new_line_index = (y * (size * 2 + 1) + (2 * size));
            if (new_line_index < (2 * size + 1) * size - 1) {
                new_bytes[new_line_index] = '\n';
            }
        }

        y = 0;
        find_pos: while (y < size) : (y += 1) {
            x = 0;
            while (x < 2 * size) : (x += 1) {
                const new_index = (y * (2 * size + 1)) + x;
                if (new_bytes[new_index] == '@') {
                    new_bytes[new_index] = '.';
                    break :find_pos;
                }
            }
        }

        return Grid{ .bytes = new_bytes, .size = size, .cur_x = x, .cur_y = y, .allocator = allocator };
    }

    fn deinit(self: *Grid) void {
        self.allocator.free(self.bytes);
    }

    fn at(self: *Grid, x: usize, y: usize) u8 {
        const index = y * (self.size * 2 + 1) + x;
        return self.bytes[index];
    }

    fn print(self: *Grid) !void {
        const stdout = std.io.getStdOut().writer();
        var y: usize = 0;
        while (y < self.size) : (y += 1) {
            var x: usize = 0;
            while (x < self.size * 2) : (x += 1) {
                if (x == self.cur_x and y == self.cur_y) {
                    try stdout.print("@", .{});
                } else {
                    try stdout.print("{c}", .{self.at(x, y)});
                }
            }
            try stdout.print("\n", .{});
        }
    }

    fn setAt(self: *Grid, value: u8, x: usize, y: usize) void {
        const index = y * (self.size * 2 + 1) + x;
        self.bytes[index] = value;
    }

    fn sumOfGPSOfBoxes(self: *Grid) usize {
        var sum: usize = 0;
        var y: usize = 0;
        while (y < self.size) : (y += 1) {
            var x: usize = 0;
            while (x < self.size * 2) : (x += 1) {
                const value = self.at(x, y);
                if (value == '[') {
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
        while (end_x < 2 * self.size - 1) : (end_x += 1) {
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
        const up_value = self.at(self.cur_x, self.cur_y - 1);
        if (up_value == '[' or up_value == ']') {
            const moved = self.moveUp(self.cur_x, self.cur_y - 1, false);
            if (moved) {
                self.cur_y = self.cur_y - 1;
            }
        } else if (up_value == '.') {
            self.cur_y = self.cur_y - 1;
        }
    }

    fn executeDown(self: *Grid) void {
        const down_value = self.at(self.cur_x, self.cur_y + 1);
        if (down_value == '[' or down_value == ']') {
            const moved = self.moveDown(self.cur_x, self.cur_y + 1, false);
            if (moved) {
                self.cur_y = self.cur_y + 1;
            }
        } else if (down_value == '.') {
            self.cur_y = self.cur_y + 1;
        }
    }

    fn moveUp(self: *Grid, x: usize, y: usize, dryrun: bool) bool {
        if (self.at(x, y) == '[') {
            if (self.at(x, y - 1) == '#' or self.at(x + 1, y - 1) == '#') {
                return false;
            }

            if (self.at(x, y - 1) != '.' or self.at(x + 1, y - 1) != '.') {
                if (self.at(x, y - 1) != '.') {
                    if (!self.moveUp(x, y - 1, true)) return false;
                }

                if (self.at(x + 1, y - 1) != '.') {
                    if (!self.moveUp(x + 1, y - 1, true)) return false;
                }

                if (!dryrun) {
                    _ = self.moveUp(x, y - 1, false);
                    if (self.at(x + 1, y - 1) != '.') {
                        _ = self.moveUp(x + 1, y - 1, false);
                    }
                } else {
                    return true;
                }
            }

            if (self.at(x, y - 1) == '.' and self.at(x + 1, y - 1) == '.') {
                if (!dryrun) {
                    self.setAt('[', x, y - 1);
                    self.setAt(']', x + 1, y - 1);
                    self.setAt('.', x, y);
                    self.setAt('.', x + 1, y);
                }
                return true;
            }
        } else if (self.at(x, y) == ']') {
            if (self.at(x, y - 1) == '#' or self.at(x - 1, y - 1) == '#') {
                return false;
            }

            if (self.at(x, y - 1) != '.' or self.at(x - 1, y - 1) != '.') {
                if (self.at(x, y - 1) != '.') {
                    if (!self.moveUp(x, y - 1, true)) return false;
                }

                if (self.at(x - 1, y - 1) != '.') {
                    if (!self.moveUp(x - 1, y - 1, true)) return false;
                }

                if (!dryrun) {
                    _ = self.moveUp(x, y - 1, false);
                    if (self.at(x - 1, y - 1) != '.') {
                        _ = self.moveUp(x - 1, y - 1, false);
                    }
                } else {
                    return true;
                }
            }

            if (self.at(x, y - 1) == '.' and self.at(x - 1, y - 1) == '.') {
                if (!dryrun) {
                    self.setAt('[', x - 1, y - 1);
                    self.setAt(']', x, y - 1);
                    self.setAt('.', x, y);
                    self.setAt('.', x - 1, y);
                }
                return true;
            }
        }

        return false;
    }

    fn moveDown(self: *Grid, x: usize, y: usize, dryrun: bool) bool {
        if (self.at(x, y) == '[') {
            if (self.at(x, y + 1) == '#' or self.at(x + 1, y + 1) == '#') {
                return false;
            }

            if (self.at(x, y + 1) != '.' or self.at(x + 1, y + 1) != '.') {
                if (self.at(x, y + 1) != '.') {
                    if (!self.moveDown(x, y + 1, true)) return false;
                }

                if (self.at(x + 1, y + 1) != '.') {
                    if (!self.moveDown(x + 1, y + 1, true)) return false;
                }

                if (!dryrun) {
                    _ = self.moveDown(x, y + 1, false);
                    if (self.at(x + 1, y + 1) != '.') {
                        _ = self.moveDown(x + 1, y + 1, false);
                    }
                } else {
                    return true;
                }
            }

            if (self.at(x, y + 1) == '.' and self.at(x + 1, y + 1) == '.') {
                if (!dryrun) {
                    self.setAt('[', x, y + 1);
                    self.setAt(']', x + 1, y + 1);
                    self.setAt('.', x, y);
                    self.setAt('.', x + 1, y);
                }
                return true;
            }
        } else if (self.at(x, y) == ']') {
            if (self.at(x, y + 1) == '#' or self.at(x - 1, y + 1) == '#') {
                return false;
            }

            if (self.at(x, y + 1) != '.' or self.at(x - 1, y + 1) != '.') {
                if (self.at(x, y + 1) != '.') {
                    if (!self.moveDown(x, y + 1, true)) return false;
                }

                if (self.at(x - 1, y + 1) != '.') {
                    if (!self.moveDown(x - 1, y + 1, true)) return false;
                }

                if (!dryrun) {
                    _ = self.moveDown(x, y + 1, false);
                    if (self.at(x - 1, y + 1) != '.') {
                        _ = self.moveDown(x - 1, y + 1, false);
                    }
                } else {
                    return true;
                }
            }

            if (self.at(x, y + 1) == '.' and self.at(x - 1, y + 1) == '.') {
                if (!dryrun) {
                    self.setAt('[', x - 1, y + 1);
                    self.setAt(']', x, y + 1);
                    self.setAt('.', x, y);
                    self.setAt('.', x - 1, y);
                }
                return true;
            }
        }

        return false;
    }
};

fn findEndOfGrid(input: []const u8) usize {
    var index: usize = 0;
    while (index < input.len - 1) : (index += 1) {
        if (input[index] == '\n' and input[index + 1] == '\n') return index;
    }

    return input.len;
}

const start_sync = "\x1b[?2026h";
const up_one_line = "\x1bM";
const clear = "\x1b[J";
const finish_sync = "\x1b[?2026l";

fn handle_sigint(_: c_int) callconv(.C) void {
    _ = std.c.printf("%s", clear);
    std.process.exit(0);
}

pub fn main() !void {
    const is_posix = switch (builtin.os.tag) {
        .linux, .macos, .freebsd, .netbsd, .openbsd, .dragonfly, .solaris, .haiku => true,
        else => false,
    };
    if (is_posix) {
        // Register SIGINT handler
        posix.sigaction(posix.SIG.INT, &posix.Sigaction{
            .handler = .{ .handler = handle_sigint },
            .mask = posix.empty_sigset,
            .flags = 0,
        }, null);
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY_LEAK");
    }

    const grid_end_pos = findEndOfGrid(INPUT);
    if (grid_end_pos >= INPUT.len) unreachable;

    var grid = try Grid.init(allocator, INPUT[0..grid_end_pos], 50);
    defer grid.deinit();

    const terminal = std.io.getStdOut();
    var command_index: usize = grid_end_pos + 1;

    var reader_buffer: [1]u8 = undefined;

    while (command_index < INPUT.len) {
        _ = try std.io.getStdIn().read(&reader_buffer);
        if (reader_buffer[0] == 'q') break;

        _ = try terminal.writeAll(start_sync);
        _ = try terminal.writeAll(clear);

        while (INPUT[command_index] == '\n' and command_index < INPUT.len) : (command_index += 1) {}

        const cur_command = INPUT[command_index];
        grid.execute(cur_command);
        const bytes_to_print = try std.fmt.allocPrint(allocator, "Executed command: {c}\n", .{cur_command});
        try terminal.writeAll(bytes_to_print);
        allocator.free(bytes_to_print);
        try grid.print();
        command_index += 1;

        while (INPUT[command_index] == '\n' and command_index < INPUT.len) : (command_index += 1) {}

        const next_command = INPUT[command_index];
        const next_bytes_to_print = try std.fmt.allocPrint(allocator, "Executed command: {c}\n", .{next_command});
        try terminal.writeAll(next_bytes_to_print);
        allocator.free(next_bytes_to_print);

        _ = try terminal.writeAll("\r");
        for (0..grid.size + 3) |_| {
            _ = try terminal.writeAll(up_one_line);
        }
        _ = try terminal.writeAll(finish_sync);
    }
}

test "small example expansion + step by step" {
    const pre_expansion =
        \\#######
        \\#...#.#
        \\#.....#
        \\#..OO@#
        \\#..O..#
        \\#.....#
        \\#######
    ;
    const allocator = std.testing.allocator;
    var grid = try Grid.init(allocator, pre_expansion[0..], 7);
    defer grid.deinit();

    const expected_after_expansion =
        \\##############
        \\##......##..##
        \\##..........##
        \\##....[][]@.##
        \\##....[]....##
        \\##..........##
        \\##############
    ;
    grid.setAt('@', grid.cur_x, grid.cur_y);
    try std.testing.expectEqualSlices(u8, expected_after_expansion, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]@..##
        \\##....[]....##
        \\##..........##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('v');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_down =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]...##
        \\##....[].@..##
        \\##..........##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_down, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('v');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_down_2 =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]...##
        \\##....[]....##
        \\##.......@..##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_down_2, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left_2 =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]...##
        \\##....[]....##
        \\##......@...##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left_2, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left_3 =
        \\##############
        \\##......##..##
        \\##..........##
        \\##...[][]...##
        \\##....[]....##
        \\##.....@....##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left_3, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('^');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_up =
        \\##############
        \\##......##..##
        \\##...[][]...##
        \\##....[]....##
        \\##.....@....##
        \\##..........##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_up, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('^');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    try std.testing.expectEqualSlices(u8, expected_after_up, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left_4 =
        \\##############
        \\##......##..##
        \\##...[][]...##
        \\##....[]....##
        \\##....@.....##
        \\##..........##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left_4, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('<');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_left_5 =
        \\##############
        \\##......##..##
        \\##...[][]...##
        \\##....[]....##
        \\##...@......##
        \\##..........##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_left_5, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.execute('^');
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_up_2 =
        \\##############
        \\##......##..##
        \\##...[][]...##
        \\##...@[]....##
        \\##..........##
        \\##..........##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_up_2, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.executeAll("<^^^>v");
    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_down_3 =
        \\##############
        \\##......##..##
        \\##...@.[]...##
        \\##...[].....##
        \\##....[]....##
        \\##..........##
        \\##############
    ;
    try std.testing.expectEqualSlices(u8, expected_after_down_3, grid.bytes);
}

test "big example final + gps" {
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

    const expected_final =
        \\####################
        \\##[].......[].[][]##
        \\##[]...........[].##
        \\##[]........[][][]##
        \\##[]......[]....[]##
        \\##..##......[]....##
        \\##..[]............##
        \\##..@......[].[][]##
        \\##......[][]..[]..##
        \\####################
    ;

    const grid_end_pos = findEndOfGrid(bigger_example);
    if (grid_end_pos >= bigger_example.len) {
        unreachable;
    }

    const allocator = std.testing.allocator;

    var grid = try Grid.init(allocator, bigger_example[0..grid_end_pos], 10);
    defer grid.deinit();

    grid.setAt('@', grid.cur_x, grid.cur_y);
    const expected_after_expansion =
        \\####################
        \\##....[]....[]..[]##
        \\##............[]..##
        \\##..[][]....[]..[]##
        \\##....[]@.....[]..##
        \\##[]##....[]......##
        \\##[]....[]....[]..##
        \\##..[][]..[]..[][]##
        \\##........[]......##
        \\####################
    ;
    try std.testing.expectEqualSlices(u8, expected_after_expansion, grid.bytes);

    grid.setAt('.', grid.cur_x, grid.cur_y);

    grid.executeAll(bigger_example[grid_end_pos + 1 ..]);
    grid.setAt('@', grid.cur_x, grid.cur_y);

    try std.testing.expectEqualSlices(u8, expected_final, grid.bytes);
    try std.testing.expectEqual(9021, grid.sumOfGPSOfBoxes());
}
