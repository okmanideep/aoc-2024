const std = @import("std");
const input = @embedFile("inputs/day2.txt");

const ReportType = enum { inc, dec, unknown };

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var reports = std.mem.tokenizeScalar(u8, input, '\n');

    var safe_report_count: usize = 0;
    while (reports.next()) |report| {
        const is_safe = check_safe_report(report);
        if (is_safe) {
            safe_report_count += 1;
        }
    }

    try stdout.print("Safe Report Count: {}\n", .{safe_report_count});
}

pub fn check_safe_report(report: []const u8) bool {
    var levels = std.mem.tokenizeScalar(u8, report, ' ');
    var report_type = ReportType.unknown;
    var cur_level: i16 = -1;
    var is_safe = true;

    while (levels.next()) |level_as_string| {
        const level = std.fmt.parseInt(i16, level_as_string, 10) catch unreachable;
        if (cur_level < 0) {
            cur_level = level;
        } else if (report_type == .unknown) {
            report_type = if (level > cur_level) .inc else .dec;
            is_safe = is_safe and check_safe(cur_level, level, report_type);
        } else {
            is_safe = is_safe and check_safe(cur_level, level, report_type);
        }

        if (!is_safe) {
            break;
        }

        cur_level = level;
    }

    return is_safe;
}

inline fn check_safe(cur_level: i16, next_level: i16, report_type: ReportType) bool {
    if (report_type == .unknown) unreachable;

    var diff = next_level - cur_level;
    if (report_type == .dec) {
        diff = -diff;
    }
    return diff >= 1 and diff <= 3;
}

test "check safe report" {
    const safe_report = "8 7 4 2 1";
    try std.testing.expectEqual(true, check_safe_report(safe_report));
}
