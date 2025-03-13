const std = @import("std");
const input = @embedFile("inputs/day1.txt");

const INPUT_LENGTH = 1000;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var first_items: [INPUT_LENGTH]i32 = undefined;
    var second_items: [INPUT_LENGTH]i32 = undefined;

    var item_count: usize = 0;
    while (item_count < INPUT_LENGTH) : (item_count += 1) {
        const start = item_count * 14;
        // parse first 5 bytes as i32
        first_items[item_count] = parseDigitsAsI32(@ptrCast(input[start .. start + 5]));
        second_items[item_count] = parseDigitsAsI32(@ptrCast(input[start + 8 .. start + 13]));
    }
    var score: i64 = 0;

    var map = std.AutoHashMap(i32, i32).init(std.heap.page_allocator);
    defer map.deinit();

    for (second_items) |item| {
        const count: i32 = map.get(item) orelse 0;
        try map.put(item, count + 1);
    }

    for (first_items) |item| {
        const count: i32 = map.get(item) orelse 0;
        score = score + item * count;
    }

    try stdout.print("Similarity Score: {}\n", .{score});
}

fn parseDigitsAsI32(bytes: *const [5]u8) i32 {
    return std.fmt.parseInt(i32, bytes, 10) catch unreachable;
}
