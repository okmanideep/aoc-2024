const std = @import("std");

inline fn mix(secret: u64, value: u64) u64 {
    return secret ^ value;
}

const PRUNE_VALUE = std.math.pow(u64, 2, 24);

inline fn prune(secret: u64) u64 {
    return secret % PRUNE_VALUE;
}

fn computeNextSecret(initial_secret: u64) u64 {
    // Calculate the result of multiplying the secret number by 64. Then, mix this result into the secret number. Finally, prune the secret number
    var secret = initial_secret;
    secret = mix(secret, secret << 6);
    secret = prune(secret);
    secret = mix(secret, secret >> 5);
    secret = prune(secret);
    secret = mix(secret, secret << 11);
    secret = prune(secret);
    return secret;
}

fn computeSumOfNthConsecuteSecret(input: []const u8, n: usize) !u64 {
    var result: u64 = 0;
    var line_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_tokenizer.next()) |num_as_string| {
        var secret = try std.fmt.parseInt(u64, num_as_string, 10);
        for(0..n) |_| {
            secret = computeNextSecret(secret);
        }
        result += secret;
    }
    return result;
}

const INPUT = @embedFile("inputs/day22.txt");
pub fn main() !void {
    const result = try computeSumOfNthConsecuteSecret(INPUT, 2000);

    std.debug.print("Result: {}\n", .{result});
}

test "10 consecutive secrets of 123" {
    const results = [10]u64{15887950, 16495136, 527345, 704524, 1553684, 12683156, 11100544, 12249484, 7753432, 5908254 };
    var secret: u64 = 123;
    for (0..10) |i| {
        secret = computeNextSecret(secret);
        try std.testing.expectEqual(results[i], secret);
    }
}

test "aoc example" {
    const input =
        \\1
        \\10
        \\100
        \\2024
    ;

    try std.testing.expectEqual(37327623, try computeSumOfNthConsecuteSecret(input, 2000));
}
