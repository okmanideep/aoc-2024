const std = @import("std");
const ArrayList = std.ArrayList;
const INPUT = @embedFile("inputs/day7.txt");

const TEST_INPUT = @embedFile("inputs/day7-test.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    var all_num_list = ArrayList(u64).init(allocator);
    defer all_num_list.deinit();

    var result: u64 = 0;

    var lineTokenizer = std.mem.tokenizeScalar(u8, INPUT, '\n');
    while (lineTokenizer.next()) |line| {
        const eq = try parse(line, &all_num_list);
        if (canMatchTargetWithOperations(eq.nums, eq.target)) {
            result += eq.target;
        }
    }

    try std.io.getStdOut().writer().print("Result: {d}\n", .{result});
}

const Equation = struct {
    target: u64,
    nums: []u64,
};

const ParsingError = error{ NoColonInInput, Overflow, InvalidCharacter };

fn parse(line: []const u8, all_num_list: *ArrayList(u64)) ParsingError!Equation {
    var colon_pos: usize = 0;
    while (colon_pos < line.len) : (colon_pos += 1) {
        if (line[colon_pos] == ':') break;
    }
    if (colon_pos >= line.len) return ParsingError.NoColonInInput;

    const target = try std.fmt.parseInt(u64, line[0..colon_pos], 10);

    const starting_len = all_num_list.items.len;

    var numbersTokenizer = std.mem.tokenizeAny(u8, line[colon_pos..], " :\n\r");
    while (numbersTokenizer.next()) |number_as_string| {
        const number = try std.fmt.parseInt(u64, number_as_string, 10);
        all_num_list.append(number) catch {
            return ParsingError.Overflow;
        };
    }
    const final_len = all_num_list.items.len;

    return Equation{ .target = target, .nums = all_num_list.items[starting_len..final_len] };
}

fn canMatchTargetWithOperations(nums: []u64, target: u64) bool {
    const length: u4 = @intCast(nums.len);

    var overrideOperationBits: u16 = 0;
    const maxValueForOperationsAsBits = std.math.pow(u16, 2, length - 1) - 1;
    while (overrideOperationBits <= maxValueForOperationsAsBits) : (overrideOperationBits += 1) {
        var operationsAsBits: u16 = 0;
        while (operationsAsBits <= maxValueForOperationsAsBits) : (operationsAsBits = nextOperationBits(operationsAsBits, overrideOperationBits, length)) {
            if (operationsMatchTarget(nums, operationsAsBits, overrideOperationBits, target)) return true;
        }
    }

    return false;
}

/// Optimisation for speed, elimating operations which are redundant
/// if override is set, the operation bit doesn't matter, so only
/// considering 0 as the valid operation bit when override bit is set to
/// get rid of redundant computations
fn nextOperationBits(operationsAsBits: u16, overrideOperationBits: u16, bitLength: u4) u16 {
    var next = operationsAsBits + 1;
    const maxValueForOperationsAsBits = std.math.pow(u16, 2, bitLength - 1) - 1;
    valid_next: while (next <= maxValueForOperationsAsBits) : (next += 1) {
        var pos: u4 = 0;
        while (pos < bitLength) : (pos += 1) {
            if (isBitSet(overrideOperationBits, pos) and isBitSet(next, pos)) {
                continue :valid_next;
            }
        }
        return next;
    }

    // std.io.getStdOut().writer().print("{b}\n{b}\n\n{b}\n\n---\n", .{ operationsAsBits, next, overrideOperationBits }) catch unreachable;

    return next;
}

fn isBitSet(value: u16, position: u4) bool {
    return (value & (@as(u16, 1) << position)) != 0;
}

fn combine(left: u64, right: u64) u64 {
    return left * std.math.pow(u64, 10, numberOfDigitsInDecimal(right)) + right;
}

fn numberOfDigitsInDecimal(value: u64) u32 {
    var result: u32 = 0;
    var cur_value = value;
    while (cur_value > 0) {
        cur_value /= 10;
        result += 1;
    }
    return result;
}

fn operationsMatchTarget(nums: []u64, operationsAsBits: u16, overrideOperationBits: u16, target: u64) bool {
    var result: u64 = nums[0];
    var position: u4 = 0;

    for (nums[1..]) |num| {
        if (isBitSet(overrideOperationBits, position)) {
            result = combine(result, num);
        } else if (isBitSet(operationsAsBits, position)) {
            result = result * num;
        } else {
            result = result + num;
        }

        if (result > target) return false;
        position += 1;
    }

    if (result == target) return true;
    return false;
}

test "aoc example" {
    const allocator = std.testing.allocator;
    var all_num_list = ArrayList(u64).init(allocator);
    defer all_num_list.deinit();

    var lineTokenizer = std.mem.tokenizeScalar(u8, TEST_INPUT, '\n');
    var index: usize = 0;
    while (lineTokenizer.next()) |line| : (index += 1) {
        const eq = try parse(line, &all_num_list);
        switch (index) {
            0 => {
                try std.testing.expectEqual(190, eq.target);
                const expected: []const u64 = &[_]u64{ 10, 19 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(true, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            1 => {
                try std.testing.expectEqual(3267, eq.target);
                const expected: []const u64 = &[_]u64{ 81, 40, 27 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(true, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            2 => {
                try std.testing.expectEqual(83, eq.target);
                const expected: []const u64 = &[_]u64{ 17, 5 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(false, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            3 => {
                try std.testing.expectEqual(156, eq.target);
                const expected: []const u64 = &[_]u64{ 15, 6 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(true, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            4 => {
                try std.testing.expectEqual(7290, eq.target);
                const expected: []const u64 = &[_]u64{ 6, 8, 6, 15 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(true, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            5 => {
                try std.testing.expectEqual(161011, eq.target);
                const expected: []const u64 = &[_]u64{ 16, 10, 13 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(false, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            6 => {
                try std.testing.expectEqual(192, eq.target);
                const expected: []const u64 = &[_]u64{ 17, 8, 14 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(true, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            7 => {
                try std.testing.expectEqual(21037, eq.target);
                const expected: []const u64 = &[_]u64{ 9, 7, 18, 13 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(false, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            8 => {
                try std.testing.expectEqual(292, eq.target);
                const expected: []const u64 = &[_]u64{ 11, 6, 16, 20 };
                try std.testing.expectEqualDeep(expected, eq.nums);
                try std.testing.expectEqual(true, canMatchTargetWithOperations(eq.nums, eq.target));
            },
            else => unreachable,
            // else => {},
        }
    }
}
