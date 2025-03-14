const std = @import("std");
const input = @embedFile("inputs/day2.txt");
// const part_1 = @import("./d02p1.zig");

const DEBUG = false;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var reports = std.mem.tokenizeScalar(u8, input, '\n');

    var safe_report_count: usize = 0;
    while (reports.next()) |report| {
        const is_safe = check_safe_report(report);
        if (is_safe) {
            safe_report_count += 1;
        } else {
            if (DEBUG) try stdout.print("NOT Safe: {s}\n", .{report});
        }
    }

    try stdout.print("Safe Report Count: {}\n", .{safe_report_count});
}

fn check_safe_report(report: []const u8) bool {
    var levels_iter = std.mem.tokenizeScalar(u8, report, ' ');
    var diffs: [10]i16 = undefined;
    var prev_level: i16 = -1;
    var diffs_count: usize = 0;

    while (levels_iter.next()) |level_as_string| {
        const level = std.fmt.parseInt(i16, level_as_string, 10) catch unreachable;
        if (prev_level > 0) {
            diffs[diffs_count] = level - prev_level;
            diffs_count += 1;
        }

        prev_level = level;
    }

    return check_safe_diffs(diffs[0..diffs_count]);
}

fn log_numbers(prefix: []const u8, diffs: []i16) void {
    if (!DEBUG) return;
    const stdout = std.io.getStdOut().writer();
    stdout.print("{s}: ", .{prefix}) catch unreachable;
    for (diffs) |diff| {
        stdout.print("{d} ", .{diff}) catch unreachable;
    }

    stdout.print("\n", .{}) catch unreachable;
}

fn check_safe_diffs(diffs: []i16) bool {
    log_numbers("Checking diffs", diffs);
    var pos_count: usize = 0;
    var neg_count: usize = 0;

    for (diffs) |diff| {
        if (diff > 0) {
            pos_count += 1;
        } else if (diff < 0) {
            neg_count += 1;
        }
    }

    if (pos_count > 2 and neg_count > 2) return false;

    for (diffs, 0..) |diff, index| {
        const same_dir = ((pos_count > neg_count) == (diff > 0));
        const safe_diff = is_safe_diff(diff);

        if (!same_dir or !safe_diff) {
            if (index == 0) {
                return check_safe_diffs_with_ignore_index(diffs, index);
            }

            // it could be this one or the previous one
            return check_safe_diffs_with_ignore_index(diffs, index) or
                check_safe_diffs_with_ignore_index(diffs, index - 1);
        }
    }

    return true;
}

fn check_safe_diffs_with_ignore_index(diffs: []i16, ignore_index: usize) bool {
    if (DEBUG) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("Ignore Index: {}\n", .{ignore_index}) catch unreachable;
        stdout.print("Diffs: ", .{}) catch unreachable;
        for (diffs) |diff| {
            stdout.print("{d} ", .{diff}) catch unreachable;
        }

        stdout.print("\n", .{}) catch unreachable;
    }
    var safe_diff_index: usize = 0;
    if (ignore_index == 0) {
        safe_diff_index = diffs.len - 1;
        var result = true;
        for (diffs[1..]) |diff| {
            const same_dir = (diff > 0) == (diffs[safe_diff_index] > 0);
            const safe_diff = is_safe_diff(diff);

            if (!same_dir or !safe_diff) {
                result = false;
                break;
            }
        }

        // need check with cumulative diff of index, index+1 if result is false
        // so only return if result is true
        if (result) return true;
    } else if (ignore_index == diffs.len - 1) {
        for (diffs[0 .. diffs.len - 1]) |diff| {
            const same_dir = (diff > 0) == (diffs[safe_diff_index] > 0);
            const safe_diff = is_safe_diff(diff);

            if (!same_dir or !safe_diff) {
                return false;
            }
        }
        return true;
    }

    for (diffs, 0..) |diff, index| {
        var value = diff;
        if (index == ignore_index or index == ignore_index + 1) {
            value = diffs[ignore_index] + diffs[ignore_index + 1];
        }

        const same_dir = (value > 0) == (diffs[safe_diff_index] > 0);
        const safe_diff = is_safe_diff(value);

        if (!same_dir or !safe_diff) {
            return false;
        }
    }
    return true;
}

inline fn is_safe_diff(diff: i16) bool {
    return @abs(diff) >= 1 and @abs(diff) <= 3;
}

test "check safe report" {
    const safe_report_1 = "8 7 4 2 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report_1));

    const unsafe_report_1 = "1 2 7 8 9";
    try std.testing.expectEqual(false, check_safe_report(unsafe_report_1));

    const unsafe_report_2 = "9 7 6 2 1";
    try std.testing.expectEqual(false, check_safe_report(unsafe_report_2));

    const safe_report_2 = "1 3 2 4 5";
    try std.testing.expectEqual(true, check_safe_report(safe_report_2));

    const safe_report_3 = "8 6 4 4 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report_3));

    const safe_report_4 = "1 3 6 7 9";
    try std.testing.expectEqual(true, check_safe_report(safe_report_4));

    const safe_report_5 = "2 1 3 6 7 9";
    try std.testing.expectEqual(true, check_safe_report(safe_report_5));

    const safe_report_6 = "57 60 62 64 63 64 65";
    try std.testing.expectEqual(true, check_safe_report(safe_report_6));

    const safe_report_7 = "5 4 3 2 1 2";
    try std.testing.expectEqual(true, check_safe_report(safe_report_7));

    const safe_report_8 = "4 5 4 3 2 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report_8));

    const safe_report_9 = "1 1 2 3 4";
    try std.testing.expectEqual(true, check_safe_report(safe_report_9));

    const safe_report_10 = "1 2 3 3 4";
    try std.testing.expectEqual(true, check_safe_report(safe_report_10));

    const safe_report_11 = "1 2 3 4 4";
    try std.testing.expectEqual(true, check_safe_report(safe_report_11));

    const safe_report_12 = "4 4 3 2 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report_12));

    const safe_report_13 = "4 3 3 2 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report_13));

    const safe_report_14 = "4 3 2 1 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report_14));

    const safe_report_15 = "1 2 6 4 5";
    try std.testing.expectEqual(true, check_safe_report(safe_report_15));

    const safe_report_16 = "6 2 3 4 5";
    try std.testing.expectEqual(true, check_safe_report(safe_report_16));

    const safe_report_17 = "1 2 3 4 9";
    try std.testing.expectEqual(true, check_safe_report(safe_report_17));

    const safe_report_18 = "5 4 3 2 6";
    try std.testing.expectEqual(true, check_safe_report(safe_report_18));

    const safe_report_19 = "1 2 3 4 9";
    try std.testing.expectEqual(true, check_safe_report(safe_report_19));

    const safe_report_20 = "9 2 3 4 5";
    try std.testing.expectEqual(true, check_safe_report(safe_report_20));

    const safe_report_21 = "1 2 3 500 4";
    try std.testing.expectEqual(true, check_safe_report(safe_report_21));

    const safe_report_22 = "1 2 3 0 4";
    try std.testing.expectEqual(true, check_safe_report(safe_report_22));

    const safe_report_23 = "1 9 10 11";
    try std.testing.expectEqual(true, check_safe_report(safe_report_23));

    const safe_report_24 = "48 46 47 49 51 54 56";
    try std.testing.expectEqual(true, check_safe_report(safe_report_24));

    const safe_report_25 = "1 1 2 3 4 5";
    try std.testing.expectEqual(true, check_safe_report(safe_report_25));

    const safe_report_26 = "1 2 3 4 5 5";
    try std.testing.expectEqual(true, check_safe_report(safe_report_26));

    const safe_report_27 = "5 1 2 3 4 5";
    try std.testing.expectEqual(true, check_safe_report(safe_report_27));

    const safe_report_28 = "1 4 3 2 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report_28));

    const safe_report_29 = "1 6 7 8 9";
    try std.testing.expectEqual(true, check_safe_report(safe_report_29));

    const safe_report_30 = "1 2 3 4 3";
    try std.testing.expectEqual(true, check_safe_report(safe_report_30));

    const safe_report_31 = "9 8 7 6 7";
    try std.testing.expectEqual(true, check_safe_report(safe_report_31));

    const safe_report_32 = "7 10 8 10 11";
    try std.testing.expectEqual(true, check_safe_report(safe_report_32));

    const safe_report_33 = "29 28 27 25 26 25 22 20";
    try std.testing.expectEqual(true, check_safe_report(safe_report_33));

    const safe_report_34 = "90 89 86 84 83 79";
    try std.testing.expectEqual(true, check_safe_report(safe_report_34));

    const safe_report_35 = "97 96 93 91 85";
    try std.testing.expectEqual(true, check_safe_report(safe_report_35));

    const safe_report_36 = "29 26 24 25 21";
    try std.testing.expectEqual(true, check_safe_report(safe_report_36));

    const safe_report_37 = "36 37 40 43 47";
    try std.testing.expectEqual(true, check_safe_report(safe_report_37));

    const safe_report_38 = "43 44 47 48 49 54";
    try std.testing.expectEqual(true, check_safe_report(safe_report_38));

    const safe_report_39 = "35 33 31 29 27 25 22 18";
    try std.testing.expectEqual(true, check_safe_report(safe_report_39));

    const safe_report_40 = "77 76 73 70 64";
    try std.testing.expectEqual(true, check_safe_report(safe_report_40));

    const safe_report_41 = "68 65 69 72 74 77 80 83";
    try std.testing.expectEqual(true, check_safe_report(safe_report_41));

    const safe_report_42 = "37 40 42 43 44 47 51";
    try std.testing.expectEqual(true, check_safe_report(safe_report_42));

    const safe_report_43 = "70 73 76 79 86";
    try std.testing.expectEqual(true, check_safe_report(safe_report_43));
}
