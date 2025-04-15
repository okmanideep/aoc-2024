const std = @import("std");
const ArrayList = std.ArrayList;

const Kind = enum { key, lock };

const Schematic = struct {
    kind: Kind,
    heights: [5]u8,

    fn matches(self: Schematic, other: Schematic) bool {
        if (self.kind == other.kind) return false;

        for (0..5) |i| {
            if (self.heights[i] + other.heights[i] > 5) return false;
        }

        return true;
    }
};

const KEY_LINE = ".....";
const LOCK_LINE = "#####";

fn parse(out: *ArrayList(Schematic), input: []const u8) !void {
    var line_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');

    var kind: ?Kind = null;
    var heights: [5]u8 = undefined;
    @memset(&heights, 0);

    while (line_tokenizer.next()) |line| {
        std.debug.assert(kind == null);
        if (std.mem.eql(u8, LOCK_LINE, line)) {
            kind = .lock;
        } else if (std.mem.eql(u8, KEY_LINE, line)) {
            kind = .key;
        } else {
            unreachable;
        }

        for (0..5) |_| {
            const data_line = line_tokenizer.next().?;
            for (0..5) |i| {
                heights[i] += if (data_line[i] == '#') 1 else 0;
            }
        }

        const schematic = Schematic{ .kind = kind.?, .heights = heights };
        try out.append(schematic);

        const last_line = line_tokenizer.next().?;
        if (kind == .lock) {
            std.debug.assert(std.mem.eql(u8, KEY_LINE, last_line));
        } else if (kind == .key) {
            std.debug.assert(std.mem.eql(u8, LOCK_LINE, last_line));
        } else {
            unreachable;
        }
        kind = null;
        @memset(&heights, 0);
    }
}

fn countMatches(slice: []Schematic) usize {
    var result: usize = 0;
    for (0..slice.len) |i| {
        const first = slice[i];
        for (i + 1..slice.len) |j| {
            const second = slice[j];
            if (first.matches(second)) result += 1;
        }
    }

    return result;
}

const INPUT = @embedFile("inputs/day25.txt");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var list = ArrayList(Schematic).init(allocator);
    defer list.deinit();

    try parse(&list, INPUT);

    const result = countMatches(list.items);
    std.debug.print("Result: {}\n", .{result});
}

test "sample input" {
    const allocator = std.testing.allocator;
    var list = ArrayList(Schematic).init(allocator);
    defer list.deinit();

    try parse(&list, SAMPLE_INPUT);

    try std.testing.expectEqual(5, list.items.len);
    try std.testing.expectEqual(3, countMatches(list.items));
}

const SAMPLE_INPUT =
    \\#####
    \\.####
    \\.####
    \\.####
    \\.#.#.
    \\.#...
    \\.....
    \\
    \\#####
    \\##.##
    \\.#.##
    \\...##
    \\...#.
    \\...#.
    \\.....
    \\
    \\.....
    \\#....
    \\#....
    \\#...#
    \\#.#.#
    \\#.###
    \\#####
    \\
    \\.....
    \\.....
    \\#.#..
    \\###..
    \\###.#
    \\###.#
    \\#####
    \\
    \\.....
    \\.....
    \\.....
    \\#....
    \\#.#..
    \\#.#.#
    \\#####
;
