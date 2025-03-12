// The Chief Historian is always present for the big Christmas sleigh launch, but nobody has seen him in months! Last anyone heard, he was visiting locations that are historically significant to the North Pole; a group of Senior Historians has asked you to accompany them as they check the places they think he was most likely to visit.
//
// As each location is checked, they will mark it on their list with a star. They figure the Chief Historian must be in one of the first fifty places they'll look, so in order to save Christmas, you need to help them get fifty stars on their list before Santa takes off on December 25th.
//
// Collect stars by solving puzzles. Two puzzles will be made available on each day in the Advent calendar; the second puzzle is unlocked when you complete the first. Each puzzle grants one star. Good luck!
//
// You haven't even left yet and the group of Elvish Senior Historians has already hit a problem: their list of locations to check is currently empty. Eventually, someone decides that the best place to check first would be the Chief Historian's office.
//
// Upon pouring into the office, everyone confirms that the Chief Historian is indeed nowhere to be found. Instead, the Elves discover an assortment of notes and lists of historically significant locations! This seems to be the planning the Chief Historian was doing before he left. Perhaps these notes can be used to determine which locations to search?
//
// Throughout the Chief's office, the historically significant locations are listed not by name but by a unique number called the location ID. To make sure they don't miss anything, The Historians split into two groups, each searching the office and trying to create their own complete list of location IDs.
//
// There's just one problem: by holding the two lists up side by side (your puzzle input), it quickly becomes clear that the lists aren't very similar. Maybe you can help The Historians reconcile their lists?
//
// For example:
//
// 3   4
// 4   3
// 2   5
// 1   3
// 3   9
// 3   3
// Maybe the lists are only off by a small amount! To find out, pair up the numbers and measure how far apart they are. Pair up the smallest number in the left list with the smallest number in the right list, then the second-smallest left number with the second-smallest right number, and so on.
//
// Within each pair, figure out how far apart the two numbers are; you'll need to add up all of those distances. For example, if you pair up a 3 from the left list with a 7 from the right list, the distance apart is 4; if you pair up a 9 with a 3, the distance apart is 6.
//
// In the example list above, the pairs and distances would be as follows:
//
// The smallest number in the left list is 1, and the smallest number in the right list is 3. The distance between them is 2.
// The second-smallest number in the left list is 2, and the second-smallest number in the right list is another 3. The distance between them is 1.
// The third-smallest number in both lists is 3, so the distance between them is 0.
// The next numbers to pair up are 3 and 4, a distance of 1.
// The fifth-smallest numbers in each list are 3 and 5, a distance of 2.
// Finally, the largest number in the left list is 4, while the largest number in the right list is 9; these are a distance 5 apart.
// To find the total distance between the left list and the right list, add up the distances between all of the pairs you found. In the example above, this is 2 + 1 + 0 + 1 + 2 + 5, a total distance of 11!
//
// Your actual left and right lists contain many location IDs. What is the total distance between your lists?
//
// To begin, get your puzzle input.
// ./input.txt
// 12 chars in each line
// xxxxx---xxxxx
// 63721   98916

// Solution Planning
// Want to go with a couple of pre allocated min heap. Read input line by line and add them to the heaps. At the end read from 0-999 in each heap and calculate distance sum

const std = @import("std");

pub fn MinHeap(comptime max_length: i16, T: type) type {
    return struct {
        const Self = @This();

        // number of items added so far
        length: usize,
        items: *[max_length]T,

        pub fn create(array: *[max_length]T) Self {
            var ctx: Self = undefined;

            ctx.items = array;
            ctx.length = 0;

            return ctx;
        }

        pub fn add(ctx: *Self, e: T) void {
            if (ctx.length >= max_length) undefined;

            if (ctx.length == 0) {
                ctx.items[0] = e;
                ctx.length += 1;
                return;
            }

            ctx.items[ctx.length] = insert(ctx.items[0..ctx.length], e);
            ctx.length += 1;
        }

        // attempts to insert the element T in the slice which is of a min heap
        // returns the last/biggest element of the resultant heap [...slice, T]
        // if e is not the last, then the slice will have the e in a sorted fashion
        // otherwise, slice is not disturbed and e is returned
        fn insert(slice: []T, e: T) T {
            for (slice, 0..) |value, i| {
                if (e < value) {
                    slice[i] = e;
                    return insert(slice[i + 1 ..], value);
                }
            }

            return e;
        }
    };
}

const INPUT_LENGTH = 1000;
const AocHeap = MinHeap(INPUT_LENGTH, i32);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Here we gooooooo\n", .{});

    var first_items: [INPUT_LENGTH]i32 = undefined;
    var first_heap = AocHeap.create(&first_items);

    var second_items: [INPUT_LENGTH]i32 = undefined;
    var second_heap = AocHeap.create(&second_items);

    // read the input line by line
    const rel_path = try std.fs.path.join(allocator, &.{ "day-1-1", "input.txt" });
    defer allocator.free(rel_path);
    const file = try std.fs.cwd().openFile(rel_path, .{ .mode = .read_only });
    defer file.close();

    var buf_reader = std.io.bufferedReaderSize(16, file.reader());
    var reader = buf_reader.reader();

    var buf: [16]u8 = undefined;
    while (first_heap.length < INPUT_LENGTH) : (@memset(&buf, 0)) {
        _ = reader.readUntilDelimiterOrEof(&buf, '\n') catch |err| {
            if (err == error.EndOfFile) {
                break;
            }
            return err;
        };

        // parse first 5 bytes as i32
        first_heap.add(parseDigitsAsI32(buf[0..5]));
        second_heap.add(parseDigitsAsI32(buf[8..13]));
    }

    var distance_sum: i64 = 0;
    var i: usize = 0;
    while (i < INPUT_LENGTH) : (i += 1) {
        const distance = @abs(second_items[i] - first_items[i]);
        try stdout.print("{}   {}   {}\n", .{ first_items[i], second_items[i], distance });
        distance_sum += distance;
    }

    try stdout.print("\nDistance sum: {}\n", .{distance_sum});
}

fn parseDigitsAsI32(bytes: *const [5]u8) i32 {
    var result: i32 = 0;
    for (bytes, 0..) |digit, pos| {
        result = result + @as(i32, @intCast((digit - '0'))) * std.math.pow(i32, 10, @intCast(4 - pos));
    }

    return result;
}

test "parsing works as expected" {
    const bytes = [5]u8{ '1', '2', '3', '4', '5' };

    const value = parseDigitsAsI32(&bytes);
    try std.testing.expectEqual(12345, value);
}

test "Heap additions work as expected when added in order" {
    var items: [1000]i32 = undefined;
    var heap = AocHeap.create(&items);
    try std.testing.expectEqual(0, heap.length);

    var i: i32 = 1;
    while (i <= 1000) : (i += 1) {
        heap.add(i);
        const expectedLength: usize = @intCast(i);
        try std.testing.expectEqual(expectedLength, heap.length);
    }

    for (heap.items, 0..) |value, index| {
        const expectedValue: i32 = @intCast(index + 1);
        try std.testing.expectEqual(expectedValue, value);
    }
}

test "Heap additions work as expected when added in reversed order" {
    var items: [1000]i32 = undefined;
    var heap = AocHeap.create(&items);
    try std.testing.expectEqual(0, heap.length);

    var i: i32 = 1;
    while (i <= 1000) : (i += 1) {
        heap.add(1000 - i + 1);
        const expectedLength: usize = @intCast(i);
        try std.testing.expectEqual(expectedLength, heap.length);
    }

    for (heap.items, 0..) |value, index| {
        const expectedValue: i32 = @intCast(index + 1);
        try std.testing.expectEqual(expectedValue, value);
    }
}
