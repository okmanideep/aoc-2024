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

const SideType = enum { left, right, up, down };

fn min(first: u8, second: u8) u8 {
    if (first < second) {
        return first;
    } else {
        return second;
    }
}

fn max(first: u8, second: u8) u8 {
    if (first > second) {
        return first;
    } else {
        return second;
    }
}

const Side = struct {
    side_type: SideType,
    from: u8,
    to: u8,
    at: u8,

    fn canJoin(self: Side, other: Side) bool {
        return self.side_type == other.side_type and
            self.at == other.at and
            (self.from == other.to or self.to == other.from);
    }

    fn join(self: Side, other: Side) Side {
        return Side{
            .side_type = self.side_type,
            .at = self.at,
            .from = min(self.from, other.from),
            .to = max(self.to, other.to),
        };
    }

    fn print(self: Side) !void {
        var side_char: u8 = undefined;
        if (self.side_type == .left) {
            side_char = '<';
        } else if (self.side_type == .right) {
            side_char = '>';
        } else if (self.side_type == .up) {
            side_char = '^';
        } else if (self.side_type == .down) {
            side_char = 'v';
        }
        try std.io.getStdOut().writer().print("{c} at {d} from {d} to {d}\n", .{ side_char, self.at, self.from, self.to });
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

fn containsRegion(slice: []Region, value: Region) bool {
    for (slice) |item| {
        if (std.meta.eql(item, value)) return true;
    }

    return false;
}

fn containsSide(slice: []Side, value: Side) bool {
    for (slice) |item| {
        if (std.meta.eql(item, value)) return true;

        if (item.side_type == value.side_type and
            item.at == value.at and
            item.from <= value.from and
            item.to >= value.to) return true;
    }

    return false;
}

fn containsPosition(slice: []Position, value: Position) bool {
    for (slice) |item| {
        if (std.meta.eql(item, value)) return true;
    }

    return false;
}

fn appendSide(list: *ArrayList(Side), side: Side) !void {
    var index: usize = list.items.len;

    for (list.items, 0..) |item, i| {
        if (item.canJoin(side)) {
            index = i;
            break;
        }
    }

    var second_index: usize = list.items.len;

    if (index < list.items.len) {
        for (list.items[index + 1 ..], index + 1..) |item, i| {
            if (item.canJoin(side)) {
                second_index = i;
                break;
            }
        }
    }

    // const stdio = std.io.getStdOut().writer();
    if (index < list.items.len and second_index < list.items.len) {
        // try stdio.print("Joining 3 Sides------\n", .{});
        // try stdio.print("1st at {d} : ", .{index});
        // try list.items[index].print();
        // try stdio.print("2nd-input: ", .{});
        // try side.print();
        // try stdio.print("3rd at {d} : ", .{second_index});
        // try list.items[second_index].print();
        list.items[index] = list.items[index].join(side).join(list.items[second_index]);
        _ = list.swapRemove(second_index);
    } else if (index < list.items.len) {
        list.items[index] = list.items[index].join(side);
    } else {
        try list.append(side);
    }
}

fn populateSides(sides: *ArrayList(Side), region: Region, grid: Grid) !void {
    for (region.slots.items) |slot| {
        // up
        if (slot.row <= 0 or grid.atP(slot) != grid.at(slot.col, slot.row - 1)) {
            try appendSide(sides, .{ .side_type = .up, .at = slot.row, .from = slot.col, .to = slot.col + 1 });
        }

        // left
        if (slot.col <= 0 or grid.atP(slot) != grid.at(slot.col - 1, slot.row)) {
            try appendSide(sides, .{ .side_type = .left, .at = slot.col, .from = slot.row, .to = slot.row + 1 });
        }

        // right
        if (slot.col >= grid.size - 1 or grid.atP(slot) != grid.at(slot.col + 1, slot.row)) {
            try appendSide(sides, .{ .side_type = .right, .at = slot.col, .from = slot.row, .to = slot.row + 1 });
        }

        // down
        if (slot.row >= grid.size - 1 or grid.atP(slot) != grid.at(slot.col, slot.row + 1)) {
            try appendSide(sides, .{ .side_type = .down, .at = slot.row, .from = slot.col, .to = slot.col + 1 });
        }
    }
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

        if (containsRegion(region_list.items, region)) continue;

        try region_list.append(region);
    }

    var price: usize = 0;
    var sides = ArrayList(Side).init(allocator);
    defer sides.deinit();

    for (region_list.items) |region| {
        try populateSides(&sides, region, grid);
        price += region.area() * sides.items.len;

        sides.clearRetainingCapacity();
    }

    try std.io.getStdOut().writer().print("Result: {d}\n", .{price});

    for (region_list.items) |region| {
        region.deinit();
        allocator.destroy(region.slots);
    }
}

fn printRegionWithSides(region: Region, sides: []Side, grid: Grid) !void {
    const stdio = std.io.getStdOut().writer();

    for (sides) |side| {
        try side.print();
    }

    var row: u8 = 0;
    while (row < grid.size) : (row += 1) {
        var col: u8 = 0;
        while (col < grid.size) : (col += 1) {
            try stdio.print(" ", .{});
            const up_side: Side = .{ .side_type = .up, .at = row, .from = col, .to = col + 1 };
            if (containsSide(sides, up_side)) {
                try stdio.print("^", .{});
            } else {
                try stdio.print(" ", .{});
            }
            try stdio.print(" ", .{});
        }
        // right top edge
        try stdio.print("\n", .{});

        col = 0;
        while (col < grid.size) : (col += 1) {
            const left_side: Side = .{ .side_type = .left, .at = col, .from = row, .to = row + 1 };
            if (containsSide(sides, left_side)) {
                try stdio.print("<", .{});
            } else {
                try stdio.print(" ", .{});
            }

            if (containsPosition(region.slots.items, .{ .col = col, .row = row })) {
                try stdio.print("{c}", .{region.value});
            } else {
                try stdio.print(".", .{});
            }

            const right_side: Side = .{ .side_type = .right, .at = col, .from = row, .to = row + 1 };
            if (containsSide(sides, right_side)) {
                try stdio.print(">", .{});
            } else {
                try stdio.print(" ", .{});
            }
        }
        try stdio.print("\n", .{});

        col = 0;
        while (col < grid.size) : (col += 1) {
            try stdio.print(" ", .{});
            const down_side: Side = .{ .side_type = .down, .at = row, .from = col, .to = col + 1 };
            if (containsSide(sides, down_side)) {
                try stdio.print("v", .{});
            } else {
                try stdio.print(" ", .{});
            }
            try stdio.print(" ", .{});
        }
        // right bottom edge
        try stdio.print("\n", .{});
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

        if (containsRegion(region_list.items, region)) continue;

        try region_list.append(region);
    }

    var price: usize = 0;
    var sides = ArrayList(Side).init(allocator);
    defer sides.deinit();

    for (region_list.items) |region| {
        try populateSides(&sides, region, grid);
        // try std.io.getStdOut().writer().print("{c}: {d}*{d}\n", .{ region.value, region.slots.items.len, sides.items.len });
        price += region.area() * sides.items.len;

        sides.clearRetainingCapacity();
    }

    for (region_list.items) |region| {
        region.deinit();
        allocator.destroy(region.slots);
    }

    try std.testing.expectEqual(1206, price);
}
