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

const CacheKey = struct { num: u64, times: u16 };
const Cache = std.AutoHashMap(CacheKey, u64);

/// returns the number of stones when one stone is blinked `times` number of times + offset
fn blink(in: u64, times: u16, cache: *Cache) !u64 {
    const key = CacheKey{ .num = in, .times = times };
    if (cache.contains(key)) {
        return cache.get(key) orelse unreachable;
    }

    if (times == 0) return 1;

    if (in == 0) {
        const result = try blink(1, times - 1, cache);
        try cache.put(.{ .num = 1, .times = times - 1 }, result);
        try cache.put(key, result);
        return result;
    } else {
        const in_digits = numberOfDigits(in);
        if (in_digits % 2 == 0) {
            const first_value = in / std.math.pow(u64, 10, in_digits / 2);
            const second_value = in - (first_value * std.math.pow(u64, 10, in_digits / 2));

            const first_key: CacheKey = .{ .num = first_value, .times = times - 1 };
            const second_key: CacheKey = .{ .num = second_value, .times = times - 1 };

            const second_result = try blink(second_value, times - 1, cache);
            try cache.put(second_key, second_result);

            const first_result = try blink(first_value, times - 1, cache);
            try cache.put(first_key, first_result);

            try cache.put(key, first_result + second_result);
            return first_result + second_result;
        } else {
            const result = try blink(in * 2024, times - 1, cache);
            try cache.put(.{ .num = in * 2024, .times = times - 1 }, result);
            try cache.put(key, result);
            return result;
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

    const INPUT = [_]u64{ 5, 62914, 65, 972, 0, 805922, 6521, 1639064 };

    var result: u64 = 0;
    var cache = Cache.init(allocator);
    defer cache.deinit();

    for (INPUT) |num| {
        result += try blink(num, 75, &cache);
    }

    try std.io.getStdOut().writer().print("Result: {}\n", .{result});
}
