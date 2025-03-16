const std = @import("std");
const input = @embedFile("inputs/day4.txt");

pub fn main() !void {
    const matrix = Matrix{ .data = input, .size = 140 };
    const xmas_count = searchXmas(&matrix);
    try std.io.getStdOut().writer().print("XMAS count: {}\n", .{xmas_count});
}

const Matrix = struct {
    data: []const u8,
    size: u8,

    fn at(self: *const Matrix, row: u8, col: u8) u8 {
        const index: usize = (@as(usize, row) * (self.size + 1) + col);
        if (index >= self.data.len) unreachable;
        return self.data[index];
    }
};

fn searchXmas(matrix: *const Matrix) u32 {
    var count: u32 = 0;
    var row: u8 = 0;

    while (row < matrix.size) : (row += 1) {
        var col: u8 = 0;
        while (col < matrix.size) : (col += 1) {
            count += searchXmasAt(matrix, row, col);
        }
    }

    return count;
}

fn searchXmasAt(matrix: *const Matrix, row: u8, col: u8) u32 {
    var count: u32 = 0;

    if (matrix.at(row, col) != 'X') return count;

    // search horizontally (E)
    if (col + 3 < matrix.size) {
        if (matrix.at(row, col + 1) == 'M' and
            matrix.at(row, col + 2) == 'A' and
            matrix.at(row, col + 3) == 'S')
        {
            count += 1;
        }
    }

    // search SE
    if (col + 3 < matrix.size and row + 3 < matrix.size) {
        if (matrix.at(row + 1, col + 1) == 'M' and
            matrix.at(row + 2, col + 2) == 'A' and
            matrix.at(row + 3, col + 3) == 'S')
        {
            count += 1;
        }
    }

    // search S
    if (row + 3 < matrix.size) {
        if (matrix.at(row + 1, col) == 'M' and
            matrix.at(row + 2, col) == 'A' and
            matrix.at(row + 3, col) == 'S')
        {
            count += 1;
        }
    }

    // search SW
    if (col >= 3 and row + 3 < matrix.size) {
        if (matrix.at(row + 1, col - 1) == 'M' and
            matrix.at(row + 2, col - 2) == 'A' and
            matrix.at(row + 3, col - 3) == 'S')
        {
            count += 1;
        }
    }

    // search W
    if (col >= 3) {
        if (matrix.at(row, col - 1) == 'M' and
            matrix.at(row, col - 2) == 'A' and
            matrix.at(row, col - 3) == 'S')
        {
            count += 1;
        }
    }

    // search NW
    if (col >= 3 and row >= 3) {
        if (matrix.at(row - 1, col - 1) == 'M' and
            matrix.at(row - 2, col - 2) == 'A' and
            matrix.at(row - 3, col - 3) == 'S')
        {
            count += 1;
        }
    }

    // search N
    if (row >= 3) {
        if (matrix.at(row - 1, col) == 'M' and
            matrix.at(row - 2, col) == 'A' and
            matrix.at(row - 3, col) == 'S')
        {
            count += 1;
        }
    }

    // search NE
    if (col + 3 < matrix.size and row >= 3) {
        if (matrix.at(row - 1, col + 1) == 'M' and
            matrix.at(row - 2, col + 2) == 'A' and
            matrix.at(row - 3, col + 3) == 'S')
        {
            count += 1;
        }
    }

    return count;
}

fn log_pos(row: u8, col: u8) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("{d},{d}\n", .{ row, col }) catch unreachable;
}

fn log(message: []const u8) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("{s}", .{message}) catch unreachable;
}

const day4_test = @embedFile("inputs/day4-test.txt");
test "aoc example" {
    const matrix = Matrix{ .data = day4_test, .size = 10 };
    const count = searchXmas(&matrix);
    try std.testing.expectEqual(18, count);
}
