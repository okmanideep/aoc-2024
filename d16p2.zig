const std = @import("std");
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const INPUT = @embedFile("inputs/day16.txt");

const Direction = enum {
    right,
    left,
    up,
    down,

    fn asChar(self: Direction) u8 {
        return switch (self) {
            .right => '>',
            .left => '<',
            .up => '^',
            .down => 'v',
        };
    }

    fn clockwise(self: Direction) Direction {
        return switch (self) {
            .right => .down,
            .left => .up,
            .up => .right,
            .down => .left,
        };
    }

    fn antiClockwise(self: Direction) Direction {
        return switch (self) {
            .right => .up,
            .left => .down,
            .up => .left,
            .down => .right,
        };
    }
};

const Position = struct {
    col: usize,
    row: usize,
    fn ahead(self: Position, dir: Direction) Position {
        const row = switch (dir) {
            .right => self.row,
            .left => self.row,
            .up => self.row - 1,
            .down => self.row + 1,
        };

        const col = switch (dir) {
            .right => self.col + 1,
            .left => self.col - 1,
            .up => self.col,
            .down => self.col,
        };

        return .{ .col = col, .row = row };
    }
};

const Grid = struct {
    bytes: []u8,
    size: usize,
    allocator: Allocator,

    fn init(allocator: Allocator, input: []const u8, size: usize) !Grid {
        var bytes = try allocator.alloc(u8, input.len);
        @memcpy(bytes, input);
        return Grid{ .bytes = bytes[0..], .size = size, .allocator = allocator };
    }

    fn deinit(self: *Grid) void {
        self.allocator.free(self.bytes);
    }

    fn at(self: *Grid, pos: Position) u8 {
        const index = pos.row * (self.size + 1) + pos.col;
        return self.bytes[index];
    }

    fn markVisited(self: *Grid, pos: Position) void {
        const index = pos.row * (self.size + 1) + pos.col;
        const char = 'O';
        self.bytes[index] = char;
    }

    fn count(self: *Grid, char: u8) u32 {
        var result: u32 = 0;

        for (self.bytes) |byte| {
            if (byte == char) result += 1;
        }

        return result;
    }

    fn print(self: *Grid) !void {
        var writer = std.io.getStdOut().writer();
        try writer.writeAll(self.bytes);
    }
};

fn contains_pos(list: []Position, pos: Position) bool {
    var result = false;
    for (list) |p| {
        if (std.meta.eql(p, pos)) {
            result = true;
            break;
        }
    }
    return result;
}

fn contains_loc(list: []Location, loc: Location) bool {
    var result = false;
    for (list) |l| {
        if (std.meta.eql(l, loc)) {
            result = true;
            break;
        }
    }
    return result;
}

const Location = struct {
    pos: Position,
    dir: Direction,

    fn ahead(self: Location) Location {
        const row = switch (self.dir) {
            .right => self.pos.row,
            .left => self.pos.row,
            .up => self.pos.row - 1,
            .down => self.pos.row + 1,
        };

        const col = switch (self.dir) {
            .right => self.pos.col + 1,
            .left => self.pos.col - 1,
            .up => self.pos.col,
            .down => self.pos.col,
        };

        const pos: Position = .{ .col = col, .row = row };
        return .{ .pos = pos, .dir = self.dir };
    }

    fn behind(self: Location) Location {
        const row = switch (self.dir) {
            .right => self.pos.row,
            .left => self.pos.row,
            .up => self.pos.row + 1,
            .down => self.pos.row - 1,
        };

        const col = switch (self.dir) {
            .right => self.pos.col - 1,
            .left => self.pos.col + 1,
            .up => self.pos.col,
            .down => self.pos.col,
        };

        const pos: Position = .{ .col = col, .row = row };
        return .{ .pos = pos, .dir = self.dir };
    }

    fn clockwise(self: Location) Location {
        return .{ .pos = self.pos, .dir = self.dir.clockwise() };
    }

    fn antiClockwise(self: Location) Location {
        return .{ .pos = self.pos, .dir = self.dir.antiClockwise() };
    }
};

const Destination = struct {
    loc: Location,
    distance: u64,
};

fn binarySearch(items: []Destination, des: Destination) usize {
    var start: usize = 0;
    var end: usize = items.len; // exclusive
    var cur: usize = start;
    while (start < end) {
        cur = start + ((end - start) / 2);
        if (items[cur].distance == des.distance) return cur;

        if (items[cur].distance < des.distance) {
            end = cur;
        } else {
            start = cur + 1;
        }
    }

    return cur;
}

const DestinationQueue = struct {
    // descending order of distance for easy pop
    list: *ArrayList(Destination),
    allocator: Allocator,

    fn init(allocator: Allocator) !DestinationQueue {
        const list_ptr = try allocator.create(ArrayList(Destination));
        list_ptr.* = ArrayList(Destination).init(allocator);
        return DestinationQueue{ .list = list_ptr, .allocator = allocator };
    }

    fn deinit(self: *DestinationQueue) void {
        self.list.deinit();
        self.allocator.destroy(self.list);
    }

    fn append(self: *DestinationQueue, des: Destination) !void {
        const index_to_insert = binarySearch(self.list.items, des);
        try self.list.insert(index_to_insert, des);
    }

    fn pop(self: *DestinationQueue) ?Destination {
        return self.list.pop();
    }
};

const DistanceStore = AutoHashMap(Location, u64);
const VisitedSet = AutoHashMap(Location, void);

fn traverseDijkstra(grid: *Grid, start: Location, end_pos: Position, store: *DistanceStore, allocator: Allocator) !Location {
    var visited = VisitedSet.init(allocator);
    defer visited.deinit();

    var queue = try DestinationQueue.init(allocator);
    defer queue.deinit();

    try queue.append(.{ .distance = 0, .loc = start });

    while (queue.pop()) |destination| {
        if (!visited.contains(destination.loc)) {
            try visit(grid, destination.loc, store, &queue, &visited, destination.distance);
        }
    }

    const ending_loc_from_left: Location = .{ .pos = end_pos, .dir = .right };
    const ending_loc_from_down: Location = .{ .pos = end_pos, .dir = .up };
    var least_distance: u64 = MAX;
    var end_loc: Location = undefined;
    if (store.get(ending_loc_from_left)) |distance| {
        if (distance < least_distance) {
            least_distance = distance;
            end_loc = ending_loc_from_left;
        }
    }

    if (store.get(ending_loc_from_down)) |distance| {
        if (distance < least_distance) {
            least_distance = distance;
            end_loc = ending_loc_from_down;
        }
    }

    return end_loc;
}

fn update_store(store: *DistanceStore, loc: Location, distance: u64) !void {
    if (store.get(loc)) |dis_in_store| {
        if (dis_in_store > distance) {
            try store.put(loc, distance);
        }
    } else {
        try store.put(loc, distance);
    }
}

fn visit(grid: *Grid, loc: Location, store: *DistanceStore, queue: *DestinationQueue, visited: *VisitedSet, distance: u64) !void {
    if (grid.at(loc.pos) == 'E') {
        return;
    }

    try visited.put(loc, {});

    const ahead = loc.ahead();
    if (grid.at(ahead.pos) != '#' and !visited.contains(ahead)) {
        try update_store(store, ahead, distance + 1);
        try queue.append(.{ .distance = distance + 1, .loc = ahead });
    }

    const cw = loc.clockwise();
    if (!visited.contains(cw)) {
        try update_store(store, cw, distance + 1000);
        try queue.append(.{ .distance = distance + 1000, .loc = cw });
    }

    const acw = loc.antiClockwise();
    if (!visited.contains(acw)) {
        try update_store(store, acw, distance + 1000);
        try queue.append(.{ .distance = distance + 1000, .loc = acw });
    }
}

fn markBestPath(grid: *Grid, store: *DistanceStore, start_loc: Location, end_loc: Location) !void {
    grid.markVisited(end_loc.pos);

    const end_score = store.get(end_loc) orelse unreachable;
    const behind = end_loc.behind();
    if (store.get(behind)) |behind_score| {
        if (behind_score + 1 == end_score) {
            try markBestPath(grid, store, start_loc, behind);
        }
    }

    const cw = end_loc.clockwise();
    if (store.get(cw)) |cw_score| {
        if (cw_score + 1000 == end_score) {
            try markBestPath(grid, store, start_loc, cw);
        }
    }

    const acw = end_loc.antiClockwise();
    if (store.get(acw)) |acw_score| {
        if (acw_score + 1000 == end_score) {
            try markBestPath(grid, store, start_loc, acw);
        }
    }
}

const MAX = std.math.maxInt(u64);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    const size = 141;
    var grid = try Grid.init(allocator, INPUT, size);
    defer grid.deinit();
    var starting_pos_index: usize = 0;
    while (starting_pos_index < INPUT.len) : (starting_pos_index += 1) {
        if (INPUT[starting_pos_index] == 'S') break;
    }

    const starting_pos_row = starting_pos_index / (size + 1);
    const starting_pos_col = starting_pos_index % (size + 1);
    const starting_pos: Position = .{ .col = starting_pos_col, .row = starting_pos_row };

    var ending_pos_index: usize = 0;
    while (ending_pos_index < INPUT.len) : (ending_pos_index += 1) {
        if (INPUT[ending_pos_index] == 'E') break;
    }

    const ending_pos_row = ending_pos_index / (size + 1);
    const ending_pos_col = ending_pos_index % (size + 1);
    const ending_pos: Position = .{ .col = ending_pos_col, .row = ending_pos_row };

    var store = DistanceStore.init(allocator);
    defer store.deinit();

    const start_loc: Location = .{ .pos = starting_pos, .dir = .right };
    const end_loc = try traverseDijkstra(&grid, start_loc, ending_pos, &store, allocator);

    try markBestPath(&grid, &store, start_loc, end_loc);

    const count = grid.count('O');
    try std.io.getStdOut().writer().print("Result: {}\n", .{count});
}

test "aoc first example" {
    const input =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
    ;

    const allocator = std.testing.allocator;
    const size = 15;
    var grid = try Grid.init(allocator, input, size);
    defer grid.deinit();
    var starting_pos_index: usize = 0;
    while (starting_pos_index < input.len) : (starting_pos_index += 1) {
        if (input[starting_pos_index] == 'S') break;
    }

    const starting_pos_row = starting_pos_index / (size + 1);
    const starting_pos_col = starting_pos_index % (size + 1);
    const starting_pos: Position = .{ .col = starting_pos_col, .row = starting_pos_row };

    var ending_pos_index: usize = 0;
    while (ending_pos_index < input.len) : (ending_pos_index += 1) {
        if (input[ending_pos_index] == 'E') break;
    }

    const ending_pos_row = ending_pos_index / (size + 1);
    const ending_pos_col = ending_pos_index % (size + 1);
    const ending_pos: Position = .{ .col = ending_pos_col, .row = ending_pos_row };

    var store = DistanceStore.init(allocator);
    defer store.deinit();

    const starting_loc: Location = .{ .pos = starting_pos, .dir = .right };
    const end_loc = try traverseDijkstra(&grid, starting_loc, ending_pos, &store, allocator);

    try markBestPath(&grid, &store, starting_loc, end_loc);

    const expected =
        \\###############
        \\#.......#....O#
        \\#.#.###.#.###O#
        \\#.....#.#...#O#
        \\#.###.#####.#O#
        \\#.#.#.......#O#
        \\#.#.#####.###O#
        \\#..OOOOOOOOO#O#
        \\###O#O#####O#O#
        \\#OOO#O....#O#O#
        \\#O#O#O###.#O#O#
        \\#OOOOO#...#O#O#
        \\#O###.#.#.#O#O#
        \\#O..#.....#OOO#
        \\###############
    ;

    try std.testing.expectEqualSlices(u8, expected, grid.bytes);
}

test "aoc second example" {
    const input =
        \\#################
        \\#...#...#...#..E#
        \\#.#.#.#.#.#.#.#.#
        \\#.#.#.#...#...#.#
        \\#.#.#.#.###.#.#.#
        \\#...#.#.#.....#.#
        \\#.#.#.#.#.#####.#
        \\#.#...#.#.#.....#
        \\#.#.#####.#.###.#
        \\#.#.#.......#...#
        \\#.#.###.#####.###
        \\#.#.#...#.....#.#
        \\#.#.#.#####.###.#
        \\#.#.#.........#.#
        \\#.#.#.#########.#
        \\#S#.............#
        \\#################
    ;

    const allocator = std.testing.allocator;
    const size = 17;
    var grid = try Grid.init(allocator, input, size);
    defer grid.deinit();
    var starting_pos_index: usize = 0;
    while (starting_pos_index < input.len) : (starting_pos_index += 1) {
        if (input[starting_pos_index] == 'S') break;
    }

    const starting_pos_row = starting_pos_index / (size + 1);
    const starting_pos_col = starting_pos_index % (size + 1);
    const starting_pos: Position = .{ .col = starting_pos_col, .row = starting_pos_row };

    var ending_pos_index: usize = 0;
    while (ending_pos_index < input.len) : (ending_pos_index += 1) {
        if (input[ending_pos_index] == 'E') break;
    }

    const ending_pos_row = ending_pos_index / (size + 1);
    const ending_pos_col = ending_pos_index % (size + 1);
    const ending_pos: Position = .{ .col = ending_pos_col, .row = ending_pos_row };

    var store = DistanceStore.init(allocator);
    defer store.deinit();

    const start_loc: Location = .{ .pos = starting_pos, .dir = .right };
    const end_loc = try traverseDijkstra(&grid, start_loc, ending_pos, &store, allocator);

    try markBestPath(&grid, &store, start_loc, end_loc);

    const expected =
        \\#################
        \\#...#...#...#..O#
        \\#.#.#.#.#.#.#.#O#
        \\#.#.#.#...#...#O#
        \\#.#.#.#.###.#.#O#
        \\#OOO#.#.#.....#O#
        \\#O#O#.#.#.#####O#
        \\#O#O..#.#.#OOOOO#
        \\#O#O#####.#O###O#
        \\#O#O#..OOOOO#OOO#
        \\#O#O###O#####O###
        \\#O#O#OOO#..OOO#.#
        \\#O#O#O#####O###.#
        \\#O#O#OOOOOOO..#.#
        \\#O#O#O#########.#
        \\#O#OOO..........#
        \\#################
    ;

    try std.testing.expectEqualSlices(u8, expected, grid.bytes);
}
