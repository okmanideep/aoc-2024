const std = @import("std");
const input = @embedFile("inputs/day3.txt");

pub fn main() !void {
    const result = computeMulOperations(input[0..], 0);
    try std.io.getStdOut().writer().print("Result: {}\n", .{result});
}

fn computeMulOperations(program: []const u8, offset: i64) i64 {
    if (program.len < 8) return offset;

    if (!std.mem.eql(u8, "mul(", program[0..4])) {
        return computeMulOperations(program[1..], offset);
    }

    const first_digit_index = 4;
    var comma_index: usize = 5;
    while (comma_index <= 8 and comma_index < program.len) : (comma_index += 1) {
        if (program[comma_index] == ',') {
            break;
        }

        // check if byte at comma_index is a digit, then continue
        if (program[comma_index] >= '0' and program[comma_index] <= '9') {
            continue;
        }

        return computeMulOperations(program[4..], offset);
    }
    if (program[comma_index] != ',') {
        return computeMulOperations(program[4..], offset);
    }

    const first_digit = std.fmt.parseInt(i16, program[first_digit_index..comma_index], 10) catch unreachable;

    const second_digit_index = comma_index + 1;
    var closing_braces_index: usize = comma_index + 2;
    if (closing_braces_index >= program.len) return offset;

    while (closing_braces_index <= comma_index + 4 and closing_braces_index < program.len) : (closing_braces_index += 1) {
        if (program[closing_braces_index] == ')') {
            break;
        }

        if (program[closing_braces_index] >= '0' and program[closing_braces_index] <= '9') {
            continue;
        }

        return computeMulOperations(program[comma_index + 1 ..], offset);
    }
    if (program[closing_braces_index] != ')') {
        return computeMulOperations(program[comma_index + 1 ..], offset);
    }

    const second_digit = std.fmt.parseInt(i16, program[second_digit_index..closing_braces_index], 10) catch unreachable;

    const newOffset = offset + (@as(i64, first_digit) * second_digit);
    return computeMulOperations(program[closing_braces_index + 1 ..], newOffset);
}

test "compute mul operations" {
    const program_1 = "mul(2,4)";
    try std.testing.expectEqual(8, computeMulOperations(program_1[0..], 0));

    const program_2 = "mul(12,4)";
    try std.testing.expectEqual(48, computeMulOperations(program_2[0..], 0));

    const program_3 = "mul(100,2)";
    try std.testing.expectEqual(200, computeMulOperations(program_3[0..], 0));

    const program_4 = "mul(2,12)";
    try std.testing.expectEqual(24, computeMulOperations(program_4[0..], 0));

    const program_5 = "mul(2,100)";
    try std.testing.expectEqual(200, computeMulOperations(program_5[0..], 0));

    const program_6 = "mul(2,2)mul(2,4)";
    try std.testing.expectEqual(12, computeMulOperations(program_6[0..], 0));

    const program_7 = "mul(2,2)mul(2,4)mul(2,4)";
    try std.testing.expectEqual(20, computeMulOperations(program_7[0..], 0));

    const program_8 = "mul(2!,2)mul(2,4)mul(2,4)";
    try std.testing.expectEqual(16, computeMulOperations(program_8[0..], 0));

    const program_9 = "mul(,2)mul(2,4)";
    try std.testing.expectEqual(8, computeMulOperations(program_9[0..], 0));

    const program_10 = "whymul(10,24)mul()";
    try std.testing.expectEqual(240, computeMulOperations(program_10[0..], 0));
}
