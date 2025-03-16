const std = @import("std");
const input = @embedFile("inputs/day4.txt");

pub fn main() !void {
    const matrix = Matrix{ .data = input, .size = 140 };
    const xmas_count = searchCrossMas(&matrix);
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

fn searchCrossMas(matrix: *const Matrix) u32 {
    var count: u32 = 0;
    var row: u8 = 0;

    while (row < matrix.size) : (row += 1) {
        var col: u8 = 0;
        while (col < matrix.size) : (col += 1) {
            count += if (hasCrossMasAt(matrix, row, col)) 1 else 0;
        }
    }

    return count;
}

fn hasCrossMasAt(matrix: *const Matrix, row: u8, col: u8) bool {
    if (matrix.at(row, col) != 'A') return false;

    if (row < 1 or col < 1) return false;

    if (row + 1 >= matrix.size or col + 1 >= matrix.size) return false;

    return ((matrix.at(row - 1, col - 1) == 'M' and
        matrix.at(row + 1, col + 1) == 'S') or
        (matrix.at(row - 1, col - 1) == 'S' and
            matrix.at(row + 1, col + 1) == 'M')) and ((matrix.at(row + 1, col - 1) == 'M' and
        matrix.at(row - 1, col + 1) == 'S') or
        (matrix.at(row + 1, col - 1) == 'S' and
            matrix.at(row - 1, col + 1) == 'M'));
}

const day4_test = @embedFile("inputs/day4-test.txt");
test "aoc example" {
    const matrix = Matrix{ .data = day4_test, .size = 10 };
    const count = searchCrossMas(&matrix);
    try std.testing.expectEqual(9, count);
}
