const std = @import("std");
const INPUT = @embedFile("inputs/day8.txt");

const TEST_INPUT = @embedFile("inputs/day8-test.txt");

const Position = struct {
    col: i8,
    row: i8,
};
const PositionList = std.ArrayList(Position);

const AntennaLocations = std.AutoHashMap(u8, *PositionList);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    var map: AntennaLocations = AntennaLocations.init(allocator);
    defer deinit(&map);

    try parse(INPUT[0..], &map);

    var antinode_list = PositionList.init(allocator);
    defer antinode_list.deinit();

    try findAntinodesForAllFrequencies(&antinode_list, &map, 50);

    try std.io.getStdOut().writer().print("Result: {d}\n", .{antinode_list.items.len});
}

fn deinit(map: *AntennaLocations) void {
    var iterator = map.valueIterator();
    while (iterator.next()) |position_list_ptr| {
        position_list_ptr.*.deinit();
        map.allocator.destroy(position_list_ptr.*);
    }

    map.deinit();
}

fn parse(data: []const u8, map: *AntennaLocations) !void {
    var lines_tokeniser = std.mem.tokenizeScalar(u8, data, '\n');
    var row: i8 = 0;
    line_iterator: while (lines_tokeniser.next()) |line| : (row += 1) {
        var col: i8 = 0;

        char_iterator: while (col < line.len) : (col += 1) {
            const index: usize = @intCast(col);
            const char = line[index];
            if (char == '\n' or char == '\r') continue :line_iterator;
            if (char == '.') continue :char_iterator;

            if (!map.contains(char)) {
                const position_list: *PositionList = try map.allocator.create(PositionList);
                position_list.* = PositionList.init(map.allocator);
                try map.put(char, position_list);
            }

            var position_list_ptr = map.get(char) orelse unreachable;
            const position: Position = .{ .col = col, .row = row };
            try position_list_ptr.append(position);
        }
    }
}

fn isValidPosition(position: Position, size: u16) bool {
    return position.col >= 0 and position.col < size and position.row >= 0 and position.row < size;
}

fn contains(list: []Position, value: Position) bool {
    for (list) |it| {
        if (std.meta.eql(it, value)) return true;
    }

    return false;
}

fn findAntinodes(out: *PositionList, freq_positions: []Position, size: u16) !void {
    var outer_i: usize = 0;
    while (outer_i < freq_positions.len) : (outer_i += 1) {
        var center_i: usize = 0;
        center: while (center_i < freq_positions.len) : (center_i += 1) {
            if (outer_i == center_i) continue :center;

            const outer = freq_positions[outer_i];
            const center = freq_positions[center_i];

            const antinode_position = Position{
                .col = 2 * center.col - outer.col,
                .row = 2 * center.row - outer.row,
            };

            if (isValidPosition(antinode_position, size) and !contains(out.items, antinode_position)) {
                try out.append(antinode_position);
            }
        }
    }
}

fn findAntinodesForAllFrequencies(out: *PositionList, map: *AntennaLocations, size: u16) !void {
    var iterator = map.iterator();

    while (iterator.next()) |entry| {
        const position_list_ptr = entry.value_ptr.*;
        try findAntinodes(out, position_list_ptr.items, size);
    }
}

test "aoc example" {
    const allocator = std.testing.allocator;

    var map: AntennaLocations = AntennaLocations.init(allocator);
    defer deinit(&map);

    try parse(TEST_INPUT[0..], &map);

    try std.testing.expectEqual(true, map.contains('0'));
    try std.testing.expectEqual(true, map.contains('A'));
    try std.testing.expectEqual(false, map.contains('.'));
    try std.testing.expectEqual(false, map.contains('a'));
    try std.testing.expectEqual(4, map.get('0').?.items.len);
    try std.testing.expectEqual(3, map.get('A').?.items.len);

    var antinode_list = PositionList.init(allocator);
    defer antinode_list.deinit();

    try findAntinodesForAllFrequencies(&antinode_list, &map, 12);

    try std.testing.expectEqual(14, antinode_list.items.len);
}
