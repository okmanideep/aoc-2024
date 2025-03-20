const std = @import("std");
const ArrayList = std.ArrayList;
// 130x130 data with new lines at the end
const INPUT = @embedFile("inputs/day6.txt");

// 10x10 data with new lines at the end
const TEST_INPUT = @embedFile("inputs/day6-test.txt");

const EncouterArrayList = ArrayList(Encounter);
const PositionArrayList = ArrayList(Position);

pub fn main() !void {
    const count = try countOptionsForTriggeringLoop(INPUT, 130);
    try std.io.getStdOut().writer().print("Result: {}\n", .{count});
}

const Position = struct {
    col: u8,
    row: u8,
};

const Direction = enum { up, right, down, left };

const Location = struct {
    position: Position,
    direction: Direction,
};

const Encounter = struct {
    position: Position, // guard's position
    before: Direction,
    after: Direction,
};

const Grid = struct {
    bytes: []u8,
    size: u8,

    fn at(self: Grid, col: u8, row: u8) usize {
        return self.bytes[self.posFor(col, row)];
    }

    fn setAt(self: Grid, value: u8, col: u8, row: u8) void {
        self.bytes[self.posFor(col, row)] = value;
    }

    fn posFor(self: Grid, col: u8, row: u8) usize {
        const pos: usize = @as(usize, @intCast(row)) * (self.size + 1) + col;
        return pos;
    }

    fn count(self: Grid, value: u8) u32 {
        var row: u8 = 0;
        var result: u32 = 0;

        while (row < self.size) : (row += 1) {
            var col: u8 = 0;
            while (col < self.size) : (col += 1) {
                if (self.at(col, row) == value) result += 1;
            }
        }

        return result;
    }

    fn search(self: Grid, value: u8) ?Position {
        var row: u8 = 0;

        while (row < self.size) : (row += 1) {
            var col: u8 = 0;
            while (col < self.size) : (col += 1) {
                if (self.at(col, row) == value) return Position{ .col = col, .row = row };
            }
        }

        return null;
    }

    fn searchMultiple(self: Grid, out: *PositionArrayList, value: u8) !void {
        var row: u8 = 0;

        while (row < self.size) : (row += 1) {
            var col: u8 = 0;
            while (col < self.size) : (col += 1) {
                if (self.at(col, row) == value) try out.append(Position{ .col = col, .row = row });
            }
        }
    }
};

const InputErrors = error{NoInitialPositionError};

fn countOptionsForTriggeringLoop(data: []const u8, size: u8) !usize {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    var copy = try ArrayList(u8).initCapacity(allocator, (size + 1) * @as(u16, @intCast(size)));
    try copy.appendSlice(data);
    defer copy.deinit();

    var grid = Grid{ .bytes = copy.items, .size = size };

    const initial_position = grid.search('^') orelse return InputErrors.NoInitialPositionError;

    const initial_location = Location{ .position = initial_position, .direction = .up };
    var encounter_list = EncouterArrayList.init(allocator);
    defer encounter_list.deinit();
    _ = try traverse(grid, initial_location, &encounter_list);

    var count: usize = 0;

    grid.setAt('^', initial_position.col, initial_position.row);

    var visited_positions = PositionArrayList.init(allocator);
    defer visited_positions.deinit();
    try grid.searchMultiple(&visited_positions, 'X');

    var encounter_list_for_reuse = EncouterArrayList.init(allocator);
    defer encounter_list_for_reuse.deinit();
    for (visited_positions.items) |position| {
        grid.setAt('#', position.col, position.row);

        const result = traverse(grid, initial_location, &encounter_list_for_reuse);
        if (result == TraverseError.LoopDetected) {
            count += 1;
        }

        grid.setAt('X', position.col, position.row);
        encounter_list_for_reuse.clearRetainingCapacity();
    }

    return count;
}

fn traverse(grid: Grid, location: Location, encounter_list: *EncouterArrayList) !Location {
    const position = location.position;

    // mark as visited
    grid.setAt('X', position.col, position.row);

    const next_location = nextLocation(grid, location) catch |err| {
        if (err == TraverseError.GoingOutOfGrid) {
            return location;
        }

        return err;
    };

    if (location.direction != next_location.direction) {
        const encounter: Encounter = .{ .position = position, .before = location.direction, .after = next_location.direction };
        if (hasEncounter(encounter_list, encounter)) {
            return TraverseError.LoopDetected;
        } else {
            try encounter_list.append(encounter);
        }
    }

    return traverse(grid, next_location, encounter_list);
}

fn hasEncounter(encounter_list: *EncouterArrayList, value: Encounter) bool {
    for (encounter_list.items) |item| {
        if (std.meta.eql(item.position, value.position) and item.before == value.before and item.after == value.after) {
            return true;
        }
    }

    return false;
}

const TraverseError = error{ GoingOutOfGrid, LoopDetected };

fn nextLocation(grid: Grid, location: Location) !Location {
    const pos = location.position;
    const dir = location.direction;

    if (dir == .up) {
        if (pos.row == 0) return TraverseError.GoingOutOfGrid;

        if (grid.at(pos.col, pos.row - 1) == '#') {
            const changed_location = Location{ .position = pos, .direction = .right };
            return nextLocation(grid, changed_location);
        }

        const next_pos = Position{ .col = pos.col, .row = pos.row - 1 };
        return Location{ .direction = .up, .position = next_pos };
    } else if (dir == .right) {
        if (pos.col >= grid.size - 1) return TraverseError.GoingOutOfGrid;

        if (grid.at(pos.col + 1, pos.row) == '#') {
            const changed_location = Location{ .position = pos, .direction = .down };
            return nextLocation(grid, changed_location);
        }

        const next_pos = Position{ .col = pos.col + 1, .row = pos.row };
        return Location{ .direction = .right, .position = next_pos };
    } else if (dir == .down) {
        if (pos.row >= grid.size - 1) return TraverseError.GoingOutOfGrid;

        if (grid.at(pos.col, pos.row + 1) == '#') {
            const changed_location = Location{ .position = pos, .direction = .left };
            return nextLocation(grid, changed_location);
        }

        const next_pos = Position{ .col = pos.col, .row = pos.row + 1 };
        return Location{ .direction = .down, .position = next_pos };
    } else if (dir == .left) {
        if (pos.col == 0) return TraverseError.GoingOutOfGrid;

        if (grid.at(pos.col - 1, pos.row) == '#') {
            const changed_location = Location{ .position = pos, .direction = .up };
            return nextLocation(grid, changed_location);
        }

        const next_pos = Position{ .col = pos.col - 1, .row = pos.row };
        return Location{ .direction = .left, .position = next_pos };
    } else {
        unreachable;
    }
}

test "aoc example" {
    const count = try countOptionsForTriggeringLoop(TEST_INPUT[0..], 10);
    try std.testing.expectEqual(6, count);
}
