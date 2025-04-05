const std = @import("std");
const Allocator = std.mem.Allocator;

const Position = struct {
    col: usize,
    row: usize,

    fn diff(self: Position, other: Position) usize {
        const row_diff = if (self.row > other.row) self.row - other.row else other.row - self.row;
        const col_diff = if (self.col > other.col) self.col - other.col else other.col - self.col;
        return row_diff + col_diff;
    }
};

const Grid = struct {
    size: usize,
    bytes: []const u8,
    allocator: Allocator,

    fn init(allocator: Allocator, input_bytes: []const u8, size: usize) !Grid {
        var bytes = try allocator.alloc(u8, input_bytes.len);
        @memcpy(bytes[0..], input_bytes);

        return Grid{ .size = size, .bytes = bytes, .allocator = allocator };
    }

    fn deinit(self: *Grid) void {
        self.allocator.free(self.bytes);
    }

    fn at(self: *Grid, col: usize, row: usize) u8 {
        return self.bytes[self.index(col, row)];
    }

    fn setAt(self: *Grid, col: usize, row: usize, value: u8) void {
        self.bytes[self.index(col, row)] = value;
    }

    fn find_pos(self: *Grid, value: u8) Position {
        for (0..self.size) |row| {
            for (0..self.size) |col| {
                if (self.at(col, row) == value) {
                    return Position{ .col = col, .row = row };
                }
            }
        }
        unreachable;
    }

    inline fn index(self: *Grid, col: usize, row: usize) usize {
        return row * (self.size + 1) + col;
    }

    fn print(self: *Grid) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll(self.bytes);
    }
};

const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const DistanceStore = AutoHashMap(Position, u64);
const VisitedSet = AutoHashMap(Position, void);
const Destination = struct { pos: Position, distance: u64, prev: ?*Destination };

fn binarySearch(items: []*Destination, des: *Destination) usize {
    var start: usize = 0;
    var end: usize = items.len; // exclusive
    var cur: usize = start;
    while (start < end) {
        cur = start + ((end - start) / 2);
        if (items[cur].*.distance == des.*.distance) return cur;

        if (items[cur].*.distance < des.*.distance) {
            end = cur;
        } else {
            start = cur + 1;
        }
    }

    return cur;
}

const DestinationQueue = struct {
    // descending order of distance for easy pop
    list: *ArrayList(*Destination),
    allocator: Allocator,

    fn init(allocator: Allocator) !DestinationQueue {
        const list_ptr = try allocator.create(ArrayList(*Destination));
        list_ptr.* = ArrayList(*Destination).init(allocator);
        return DestinationQueue{ .list = list_ptr, .allocator = allocator };
    }

    fn deinit(self: *DestinationQueue) void {
        self.list.deinit();
        self.allocator.destroy(self.list);
    }

    fn append(self: *DestinationQueue, des: *Destination) !void {
        const index_to_insert = binarySearch(self.list.items, des);
        try self.list.insert(index_to_insert, des);
    }

    fn pop(self: *DestinationQueue) ?*Destination {
        return self.list.pop();
    }
};

const TraversalError = error{NoPath};

const Traversal = struct {
    grid: *Grid,
    store: *DistanceStore,
    queue: *DestinationQueue,
    visited: *VisitedSet,
    cleanup: *ArrayList(*Destination),
    allocator: Allocator,

    fn init(allocator: Allocator, grid: *Grid) !Traversal {
        const store_ptr = try allocator.create(DistanceStore);
        store_ptr.* = DistanceStore.init(allocator);
        const visited_ptr = try allocator.create(VisitedSet);
        visited_ptr.* = VisitedSet.init(allocator);
        const queue_ptr = try allocator.create(DestinationQueue);
        queue_ptr.* = try DestinationQueue.init(allocator);
        const cleanup_list_ptr = try allocator.create(ArrayList(*Destination));
        cleanup_list_ptr.* = ArrayList(*Destination).init(allocator);

        return Traversal{ .grid = grid, .store = store_ptr, .queue = queue_ptr, .visited = visited_ptr, .cleanup = cleanup_list_ptr, .allocator = allocator };
    }

    fn deinit(self: *Traversal) void {
        self.store.deinit();
        self.queue.deinit();
        self.visited.deinit();
        for (self.cleanup.items) |item| {
            self.allocator.destroy(item);
        }
        self.cleanup.deinit();
        self.allocator.destroy(self.store);
        self.allocator.destroy(self.queue);
        self.allocator.destroy(self.visited);
        self.allocator.destroy(self.cleanup);
    }

    fn shortestPath(self: *Traversal, start: Position, end: Position) !*Destination {
        const start_destination = self.destinationPtr(start, 0, null);
        try self.queue.append(start_destination);

        while (self.queue.pop()) |destination| {
            if (std.meta.eql(end, destination.pos)) {
                return destination;
            }

            if (!self.visited.contains(destination.pos)) {
                try self.visit(destination);
            }
        }

        return TraversalError.NoPath;
    }

    fn destinationPtr(self: *Traversal, pos: Position, distance: u64, prev: ?*Destination) *Destination {
        const destination_ptr = self.allocator.create(Destination) catch unreachable;
        destination_ptr.* = Destination{ .pos = pos, .distance = distance, .prev = prev };
        self.cleanup.append(destination_ptr) catch unreachable;
        return destination_ptr;
    }

    fn visit(self: *Traversal, destination: *Destination) !void {
        const pos = destination.pos;
        const distance = destination.distance;

        try self.visited.put(pos, {});

        if (pos.col > 0) {
            const left: Position = .{ .col = pos.col - 1, .row = pos.row };
            if (self.grid.at(left.col, left.row) != '#' and !self.visited.contains(left)) {
                try self.updateStore(left, distance + 1);
                const left_destination_ptr = self.destinationPtr(left, distance + 1, destination);
                try self.queue.append(left_destination_ptr);
            }
        }

        if (pos.col < self.grid.size - 1) {
            const right: Position = .{ .col = pos.col + 1, .row = pos.row };
            if (self.grid.at(right.col, right.row) != '#' and !self.visited.contains(right)) {
                try self.updateStore(right, distance + 1);
                const right_destination_ptr = self.destinationPtr(right, distance + 1, destination);
                try self.queue.append(right_destination_ptr);
            }
        }

        if (pos.row > 0) {
            const up: Position = .{ .col = pos.col, .row = pos.row - 1 };
            if (self.grid.at(up.col, up.row) != '#' and !self.visited.contains(up)) {
                try self.updateStore(up, distance + 1);
                const up_destination_ptr = self.destinationPtr(up, distance + 1, destination);
                try self.queue.append(up_destination_ptr);
            }
        }

        if (pos.row < self.grid.size - 1) {
            const down: Position = .{ .col = pos.col, .row = pos.row + 1 };
            if (self.grid.at(down.col, down.row) != '#' and !self.visited.contains(down)) {
                try self.updateStore(down, distance + 1);
                const down_destination_ptr = self.destinationPtr(down, distance + 1, destination);
                try self.queue.append(down_destination_ptr);
            }
        }
    }

    fn updateStore(self: *Traversal, pos: Position, distance: u64) !void {
        if (self.store.get(pos)) |distance_in_store| {
            if (distance_in_store > distance) {
                try self.store.put(pos, distance);
            }
        } else {
            try self.store.put(pos, distance);
        }
    }
};

fn countAllShortcuts(allocator: Allocator, end_destination_ptr: *Destination, minSave: u64) !usize {
    var count: usize = 0;
    var destination_list = ArrayList(*Destination).init(allocator);
    defer destination_list.deinit();

    try destination_list.append(end_destination_ptr);
    var destination_ptr = end_destination_ptr;
    while (destination_ptr.prev != null) {
        destination_ptr = destination_ptr.prev.?;
        try destination_list.append(destination_ptr);
    }

    var end_index: usize = 0;
    while (end_index < destination_list.items.len - 1) : (end_index += 1) {
        var start_index: usize = destination_list.items.len - 1;
        while (start_index > end_index) : (start_index -= 1) {
            const end = destination_list.items[end_index];
            const start = destination_list.items[start_index];

            const diff = end.pos.diff(start.pos);

            if (diff <= 20 and end.distance >= start.distance + diff + minSave) {
                count += 1;
            }
        }
    }

    return count;
}

const INPUT = @embedFile("inputs/day20.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var grid = try Grid.init(allocator, INPUT, 141);
    defer grid.deinit();
    const start = grid.find_pos('S');
    const end = grid.find_pos('E');

    var traversal = try Traversal.init(allocator, &grid);
    defer traversal.deinit();
    const end_destination_ptr = try traversal.shortestPath(start, end);

    const count = try countAllShortcuts(allocator, end_destination_ptr, 100);
    std.debug.print("Result: {}\n", .{count});
}

const SAMPLE_INPUT =
    \\###############
    \\#...#...#.....#
    \\#.#.#.#.#.###.#
    \\#S#...#.#.#...#
    \\#######.#.#.###
    \\#######.#.#...#
    \\#######.#.###.#
    \\###..E#...#...#
    \\###.#######.###
    \\#...###...#...#
    \\#.#####.#.###.#
    \\#.#...#.#.#...#
    \\#.#.#.#.#.#.###
    \\#...#...#...###
    \\###############
;
