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

fn blink(out: *ArrayList(u64), in: []u64) !void {
    for (in) |num| {
        if (num == 0) {
            try out.append(1);
        } else {
            const num_digits = numberOfDigits(num);
            if (num_digits % 2 == 0) {
                const first_value = num / std.math.pow(u64, 10, num_digits / 2);
                const second_value = num - (first_value * std.math.pow(u64, 10, num_digits / 2));

                try out.append(first_value);
                try out.append(second_value);
            } else {
                try out.append(num * 2024);
            }
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

    var out = ArrayList(u64).init(allocator);
    defer out.deinit();

    var INPUT = [_]u64{ 5, 62914, 65, 972, 0, 805922, 6521, 1639064 };

    var in: []u64 = INPUT[0..];
    try blink(&out, in);
    in = try out.toOwnedSlice();

    for (0..24) |_| {
        try blink(&out, in);

        allocator.free(in);
        in = try out.toOwnedSlice();
    }

    try std.io.getStdOut().writer().print("Result: {}\n", .{in.len});
    allocator.free(in);
}

test "aoc example" {
    const allocator = std.testing.allocator;

    var out = ArrayList(u64).init(allocator);
    defer out.deinit();

    var test_in = [_]u64{ 125, 17 };

    var in: []u64 = test_in[0..];
    try blink(&out, in);
    in = try out.toOwnedSlice();

    for (0..24) |_| {
        try blink(&out, in);

        allocator.free(in);
        in = try out.toOwnedSlice();
    }
    try std.testing.expectEqual(55312, in.len);
    allocator.free(in);
}
