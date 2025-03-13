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

    std.mem.sort(i32, &first_items, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, &second_items, {}, comptime std.sort.asc(i32));

    var distance_sum: i64 = 0;
    var i: usize = 0;
    while (i < INPUT_LENGTH) : (i += 1) {
        const distance = @abs(second_items[i] - first_items[i]);
        distance_sum += distance;
    }

    try stdout.print("\nDistance sum: {}\n", .{distance_sum});
}

fn parseDigitsAsI32(bytes: *const [5]u8) i32 {
    return std.fmt.parseInt(i32, bytes, 10) catch unreachable;
}

fn quick_sort(array: []i32) void {
    if (array.len <= 1) return;

    var lo: usize = 0;
    var hi: usize = 0;
    var inc_lo = false;
    const pivot = array[array.len - 1];
    while (lo < array.len - 1 and hi < array.len - 1) {
        if (array[hi] < pivot) {
            if (inc_lo) {
                lo = lo + 1;
            } else {
                inc_lo = true;
            }

            const temp = array[lo];
            array[lo] = array[hi];
            array[hi] = temp;
        }
        hi = hi + 1;
    }
    if (inc_lo and lo < array.len - 1) {
        lo = lo + 1;
    }
    array[array.len - 1] = array[lo];
    array[lo] = pivot;

    quick_sort(array[0..lo]);
    quick_sort(array[lo + 1 ..]);
}

test "parsing works as expected" {
    const bytes = [5]u8{ '1', '2', '3', '4', '5' };

    const value = parseDigitsAsI32(&bytes);
    try std.testing.expectEqual(12345, value);
}

test "quick sort works" {
    // two item case
    var small_array = [_]i32{ 2, 1 };
    quick_sort(small_array[0..]);
    const small_expected = [_]i32{ 1, 2 };
    try std.testing.expectEqual(small_expected, small_array);

    var array = [_]i32{ 3, 2, 1, 4, 5 };
    quick_sort(array[0..]);
    const expected = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(expected, array);
}
