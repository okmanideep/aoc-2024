const std = @import("std");
const ArrayList = std.ArrayList;
const INPUT = @embedFile("inputs/day12.txt");

const TEST_INPUT = @embedFile("inputs/day12-test.txt");

const Position = struct {
    col: u8,
    row: u8,
};
const PositionList = std.ArrayList(Position);

const Grid = struct {
    bytes: []const u8,
    size: u8,

    fn from(bytes: []const u8, size: u8) Grid {
        return Grid{ .bytes = bytes, .size = size };
    }

    fn at(self: Grid, col: u8, row: u8) u8 {
        return self.bytes[self.posFor(col, row)];
    }

    fn atP(self: Grid, pos: Position) u8 {
        return self.at(pos.col, pos.row);
    }

    fn posFor(self: Grid, col: u8, row: u8) usize {
        const pos: usize = @as(usize, @intCast(row)) * (self.size + 1) + col;
        return pos;
    }
};

const Region = struct {
    value: u8,
    slots: *PositionList,

    fn deinit(self: Region) void {
        self.slots.deinit();
    }

    fn area(self: Region) usize {
        return self.slots.items.len;
    }

    fn perimeter(self: Region, grid: Grid) usize {
        var result: usize = 0;
        for (self.slots.items) |slot| {
            // up
            if (slot.row <= 0 or grid.atP(slot) != grid.at(slot.col, slot.row - 1)) {
                result += 1;
            }

            // left
            if (slot.col <= 0 or grid.atP(slot) != grid.at(slot.col - 1, slot.row)) {
                result += 1;
            }

            // right
            if (slot.col >= grid.size - 1 or grid.atP(slot) != grid.at(slot.col + 1, slot.row)) {
                result += 1;
            }

            // down
            if (slot.row >= grid.size - 1 or grid.atP(slot) != grid.at(slot.col, slot.row + 1)) {
                result += 1;
            }
        }

        return result;
    }
};

const RegionMap = std.AutoHashMap(Position, Region);

fn populateRegions(map: *RegionMap, grid: Grid) !void {
    var row: u8 = 0;
    while (row < grid.size) : (row += 1) {
        var col: u8 = 0;
        while (col < grid.size) : (col += 1) {
            const pos: Position = .{ .col = col, .row = row };
            if (!map.contains(pos)) {
                const slots_ptr = try map.allocator.create(PositionList);
                slots_ptr.* = PositionList.init(map.allocator);
                try slots_ptr.append(pos);
                const region: Region = .{ .value = grid.atP(pos), .slots = slots_ptr };
                try map.put(pos, region);
                try traverseRegion(map, grid, pos);
            }
        }
    }
}

fn traverseRegion(map: *RegionMap, grid: Grid, pos: Position) !void {
    if (pos.row > 0) {
        const up_pos: Position = .{ .col = pos.col, .row = pos.row - 1 };

        if (!map.contains(up_pos) and grid.atP(up_pos) == grid.atP(pos)) {
            const region = map.get(pos) orelse unreachable;
            try region.slots.append(up_pos);
            try map.put(up_pos, region);
            try traverseRegion(map, grid, up_pos);
        }
    }

    if (pos.col > 0) {
        const left_pos: Position = .{ .col = pos.col - 1, .row = pos.row };

        if (!map.contains(left_pos) and grid.atP(left_pos) == grid.atP(pos)) {
            const region = map.get(pos) orelse unreachable;
            try region.slots.append(left_pos);
            try map.put(left_pos, region);
            try traverseRegion(map, grid, left_pos);
        }
    }

    if (pos.col < grid.size - 1) {
        const right_pos: Position = .{ .col = pos.col + 1, .row = pos.row };

        if (!map.contains(right_pos) and grid.atP(right_pos) == grid.atP(pos)) {
            const region = map.get(pos) orelse unreachable;
            try region.slots.append(right_pos);
            try map.put(right_pos, region);
            try traverseRegion(map, grid, right_pos);
        }
    }

    if (pos.row < grid.size - 1) {
        const down_pos: Position = .{ .col = pos.col, .row = pos.row + 1 };

        if (!map.contains(down_pos) and grid.atP(down_pos) == grid.atP(pos)) {
            const region = map.get(pos) orelse unreachable;
            try region.slots.append(down_pos);
            try map.put(down_pos, region);
            try traverseRegion(map, grid, down_pos);
        }
    }
}

fn contains(slice: []Region, value: Region) bool {
    for (slice) |item| {
        if (std.meta.eql(item, value)) return true;
    }

    return false;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    var map = RegionMap.init(allocator);
    defer map.deinit();
    const grid = Grid.from(INPUT[0..], 140);

    try populateRegions(&map, grid);

    var region_list = ArrayList(Region).init(allocator);
    defer region_list.deinit();

    var iterator = map.iterator();
    while (iterator.next()) |entry| {
        const region = entry.value_ptr.*;

        if (contains(region_list.items, region)) continue;

        try region_list.append(region);
    }

    var price: usize = 0;

    for (region_list.items) |region| {
        price += region.area() * region.perimeter(grid);
    }

    try std.io.getStdOut().writer().print("Result: {d}\n", .{price});

    for (region_list.items) |region| {
        region.deinit();
        allocator.destroy(region.slots);
    }
}

test "aoc example" {
    const allocator = std.testing.allocator;

    var map = RegionMap.init(allocator);
    defer map.deinit();
    const grid = Grid.from(TEST_INPUT[0..], 10);

    try populateRegions(&map, grid);

    var region_list = ArrayList(Region).init(allocator);
    defer region_list.deinit();

    var iterator = map.iterator();
    while (iterator.next()) |entry| {
        const region = entry.value_ptr.*;

        if (contains(region_list.items, region)) continue;

        try region_list.append(region);
    }

    var price: usize = 0;

    for (region_list.items) |region| {
        price += region.area() * region.perimeter(grid);
    }

    try std.testing.expectEqual(1930, price);

    for (region_list.items) |region| {
        region.deinit();
        allocator.destroy(region.slots);
    }
}
