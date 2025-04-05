const std = @import("std");
const Allocator = std.mem.Allocator;

const Position = struct {
    col: usize,
    row: usize,
};

const Grid = struct {
    size: usize,
    bytes: []const u8,
    allocator: Allocator,

    fn init(allocator: Allocator, input_bytes: []const u8, size: usize) !Grid {
        var bytes = try allocator.alloc(u8, input_bytes.len);
        @memcpy(&bytes, input_bytes);

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
const Destination = struct { pos: Position, distance: u64, prev: ?Destination };

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

const TraversalError = error{NoPath};

const Traversal = struct {
    grid: *Grid,
    store: *DistanceStore,
    queue: *DestinationQueue,
    visited: *VisitedSet,

    fn shortestPath(grid: *Grid, start: Position, end: Position, allocator: Allocator) !Destination {
        var store = DistanceStore.init(allocator);
        defer store.deinit();
        var visited = VisitedSet.init(allocator);
        defer visited.deinit();
        var queue = try DestinationQueue.init(allocator);
        defer queue.deinit();

        var self: Traversal = .{ .grid = grid, .store = &store, .queue = &queue, .visited = &visited };
        try queue.append(.{ .pos = start, .distance = 0, .prev = null });

        while (queue.pop()) |destination| {
            if (std.meta.eql(end, destination.pos)) {
                return destination;
            }

            if (!visited.contains(destination.pos)) {
                try self.visit(destination);
            }
        }

        return TraversalError.NoPath;
    }

    fn visit(self: *Traversal, destination: Destination) !void {
        const pos = destination.pos;
        const distance = destination.distance;

        try self.visited.put(pos, {});

        if (pos.col > 0) {
            const left: Position = .{ .col = pos.col - 1, .row = pos.row };
            if (self.grid.at(left.col, left.row) != '#' and !self.visited.contains(left)) {
                try self.updateStore(left, distance + 1);
                try self.queue.append(.{ .pos = left, .distance = distance + 1, .prev = destination });
            }
        }

        if (pos.col < self.grid.size - 1) {
            const right: Position = .{ .col = pos.col + 1, .row = pos.row };
            if (self.grid.at(right.col, right.row) != '#' and !self.visited.contains(right)) {
                try self.updateStore(right, distance + 1);
                try self.queue.append(.{ .pos = right, .distance = distance + 1, .prev = destination });
            }
        }

        if (pos.row > 0) {
            const up: Position = .{ .col = pos.col, .row = pos.row - 1 };
            if (self.grid.at(up.col, up.row) != '#' and !self.visited.contains(up)) {
                try self.updateStore(up, distance + 1);
                try self.queue.append(.{ .pos = up, .distance = distance + 1, .prev = destination });
            }
        }

        if (pos.row < self.grid.size - 1) {
            const down: Position = .{ .col = pos.col, .row = pos.row + 1 };
            if (self.grid.at(down.col, down.row) != '#' and !self.visited.contains(down)) {
                try self.updateStore(down, distance + 1);
                try self.queue.append(.{ .pos = down, .distance = distance + 1, .prev = destination });
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
