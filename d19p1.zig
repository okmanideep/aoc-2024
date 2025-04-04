const std = @import("std");
const StringSet = std.StringHashMap(void);
const Allocator = std.mem.Allocator;

const PossibleCache = std.StringHashMap(bool);

fn fillTowelSet(towelSet: *StringSet, line: []const u8) !void {
    var tokenizer = std.mem.tokenizeAny(u8, line, ", \n");
    while (tokenizer.next()) |towel| {
        try towelSet.put(towel, {});
    }
}

fn isPossible(towelSet: *StringSet, cache: *PossibleCache, combo: []const u8) !bool {
    if (combo.len == 0) return true;
    if (cache.get(combo)) |result| {
        return result;
    }

    var divider: usize = 1;
    while (divider <= combo.len) : (divider += 1) {
        if (towelSet.contains(combo[0..divider]) and try isPossible(towelSet, cache, combo[divider..])) {
            try cache.put(combo, true);
            return true;
        }
    }

    try cache.put(combo, false);
    return false;
}

fn countPossible(allocator: Allocator, input: []const u8) !usize {
    var line_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    const towel_set_line = line_tokenizer.next() orelse unreachable;

    var towelSet = StringSet.init(allocator);
    defer towelSet.deinit();

    try fillTowelSet(&towelSet, towel_set_line);

    var cache = PossibleCache.init(allocator);
    defer cache.deinit();

    var count: usize = 0;
    while (line_tokenizer.next()) |line| {
        if (try isPossible(&towelSet, &cache, line[0..])) {
            // std.debug.print("Possible: {s}\n", .{line[0..]});
            count += 1;
        }
    }

    return count;
}

const INPUT = @embedFile("inputs/day19.txt");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    const count = try countPossible(allocator, INPUT);

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
    const count = try countPossible(std.testing.allocator, SAMPLE_INPUT);
    try std.testing.expectEqual(6, count);
}
