const std = @import("std");
const StringSet = std.StringHashMap(void);
const Allocator = std.mem.Allocator;

const PossibleCountCache = std.StringHashMap(usize);

fn fillTowelSet(towelSet: *StringSet, line: []const u8) !void {
    var tokenizer = std.mem.tokenizeAny(u8, line, ", \n");
    while (tokenizer.next()) |towel| {
        try towelSet.put(towel, {});
    }
}

fn countPossibilitiesForCombo(towelSet: *StringSet, cache: *PossibleCountCache, combo: []const u8, offset: usize) !usize {
    if (combo.len == 0) return offset + 1;
    if (cache.get(combo)) |result| {
        if (result > 0) return result + offset;

        return 0;
    }

    var count: usize = 0;
    var divider: usize = 1;
    while (divider <= combo.len) : (divider += 1) {
        if (towelSet.contains(combo[0..divider])) {
            const count_rest = try countPossibilitiesForCombo(towelSet, cache, combo[divider..], count);
            try cache.put(combo, count_rest);

            if (count_rest == 0) {
                continue;
            } else {
                count = count_rest;
            }
        }
    }

    if (count == 0) {
        try cache.put(combo, 0);
        return 0;
    } else {
        try cache.put(combo, count);
        return count + offset;
    }
}

fn countAllPossibilities(allocator: Allocator, input: []const u8) !usize {
    var line_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    const towel_set_line = line_tokenizer.next() orelse unreachable;

    var towelSet = StringSet.init(allocator);
    defer towelSet.deinit();

    try fillTowelSet(&towelSet, towel_set_line);

    var cache = PossibleCountCache.init(allocator);
    defer cache.deinit();

    var count: usize = 0;
    while (line_tokenizer.next()) |line| {
        const combo_count = try countPossibilitiesForCombo(&towelSet, &cache, line[0..], 0);
        // std.debug.print("Possible: {s}\n", .{line[0..]});
        if (combo_count > 0) {
            count += @as(usize, @intCast(combo_count));
        }
    }

    return count;
}

const INPUT = @embedFile("inputs/day19.txt");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    const count = try countAllPossibilities(allocator, INPUT);

    std.debug.print("Result: {}\n", .{count});
}

const SAMPLE_INPUT =
    \\r, wr, b, g, bwu, rb, gb, br
    \\
    \\brwrr
    \\bggr
    \\gbbr
    \\rrbgbr
    \\ubwu
    \\bwurrg
    \\brgr
    \\bbrgwb
;

test "sample input count" {
    const count = try countAllPossibilities(std.testing.allocator, SAMPLE_INPUT);
    try std.testing.expectEqual(16, count);
}
