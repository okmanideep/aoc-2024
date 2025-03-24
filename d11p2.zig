const std = @import("std");

const ArrayList = std.ArrayList;

fn numberOfDigits(value: u64) u32 {
    var result: u32 = 0;
    var cur_value = value;
    while (cur_value > 0) {
        cur_value /= 10;
        result += 1;
    }
    return result;
}

/// returns the number of stones when one stone is blinked `times` number of times + offset
fn blink(in: u64, times: u16, offset: u64) u64 {
    if (times == 0) return offset + 1;

    if (in == 0) {
        return blink(1, times - 1, offset);
    } else {
        const in_digits = numberOfDigits(in);
        if (in_digits % 2 == 0) {
            const first_value = in / std.math.pow(u64, 10, in_digits / 2);
            const second_value = in - (first_value * std.math.pow(u64, 10, in_digits / 2));

            const count = blink(second_value, times - 1, offset);
            return blink(first_value, times - 1, count);
        } else {
            return blink(in * 2024, times - 1, offset);
        }
    }
}

pub fn main() !void {
    const INPUT = [_]u64{ 5, 62914, 65, 972, 0, 805922, 6521, 1639064 };

    var result: u64 = 0;

    for (INPUT) |num| {
        result = blink(num, 25, result);
    }

    try std.io.getStdOut().writer().print("Result: {}\n", .{result});
}
