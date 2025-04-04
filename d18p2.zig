const std = @import("std");
const Allocator = std.mem.Allocator;
const SAMPLE_INPUT =
    \\5,4
    \\4,2
    \\4,5
    \\3,0
    \\2,1
    \\6,3
    \\2,4
    \\1,5
    \\0,6
    \\3,3
    \\2,6
    \\5,1
    \\1,2
    \\5,5
    \\2,5
    \\6,5
    \\1,4
    \\0,4
    \\6,4
    \\1,1
    \\6,1
    \\1,0
    \\0,5
    \\1,6
    \\2,0
;

const Position = struct {
    col: usize,
    row: usize,
};

const Grid = struct {
    size: usize,
    bytes: []u8,
    allocator: Allocator,

    fn init(allocator: Allocator, size: usize) !Grid {
        var bytes = try allocator.alloc(u8, (size + 1) * size - 1);
        @memset(bytes[0..], '.');
        for (0..size - 1) |i| {
            // to make it easier for printing
            bytes[(size + 1) * i + size] = '\n';
        }
        return Grid{ .bytes = bytes, .size = size, .allocator = allocator };
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

    fn clearAll(self: *Grid, value: u8) void {
        for (self.bytes, 0..) |byte, i| {
            if (byte == value) {
                self.bytes[i] = '.';
            }
        }
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
const Destination = struct {
    pos: Position,
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

const TraversalError = error{NoPath};

const Traversal = struct {
    grid: *Grid,
    store: *DistanceStore,
    queue: *DestinationQueue,
    visited: *VisitedSet,

    fn shortestDistance(grid: *Grid, start: Position, end: Position, allocator: Allocator) !u64 {
        var store = DistanceStore.init(allocator);
        defer store.deinit();
        var visited = VisitedSet.init(allocator);
        defer visited.deinit();
        var queue = try DestinationQueue.init(allocator);
        defer queue.deinit();

        var self: Traversal = .{ .grid = grid, .store = &store, .queue = &queue, .visited = &visited };
        try queue.append(.{ .pos = start, .distance = 0 });

        while (queue.pop()) |destination| {
            if (std.meta.eql(end, destination.pos)) {
                return destination.distance;
            }

            if (!visited.contains(destination.pos)) {
                try self.visit(destination.pos, destination.distance);
            }
        }

        return TraversalError.NoPath;
    }

    fn visit(self: *Traversal, pos: Position, distance: u64) !void {
        try self.visited.put(pos, {});

        if (pos.col > 0) {
            const left: Position = .{ .col = pos.col - 1, .row = pos.row };
            if (self.grid.at(left.col, left.row) != '#' and !self.visited.contains(left)) {
                try self.updateStore(left, distance + 1);
                try self.queue.append(.{ .pos = left, .distance = distance + 1 });
            }
        }

        if (pos.col < self.grid.size - 1) {
            const right: Position = .{ .col = pos.col + 1, .row = pos.row };
            if (self.grid.at(right.col, right.row) != '#' and !self.visited.contains(right)) {
                try self.updateStore(right, distance + 1);
                try self.queue.append(.{ .pos = right, .distance = distance + 1 });
            }
        }

        if (pos.row > 0) {
            const up: Position = .{ .col = pos.col, .row = pos.row - 1 };
            if (self.grid.at(up.col, up.row) != '#' and !self.visited.contains(up)) {
                try self.updateStore(up, distance + 1);
                try self.queue.append(.{ .pos = up, .distance = distance + 1 });
            }
        }

        if (pos.row < self.grid.size - 1) {
            const down: Position = .{ .col = pos.col, .row = pos.row + 1 };
            if (self.grid.at(down.col, down.row) != '#' and !self.visited.contains(down)) {
                try self.updateStore(down, distance + 1);
                try self.queue.append(.{ .pos = down, .distance = distance + 1 });
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

fn setup(grid: *Grid, input: []const u8, count: usize) !void {
    var line_num: usize = 0;
    var line_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_tokenizer.next()) |line| : (line_num += 1) {
        if (line_num >= count) break;
        var comma_tokenizer = std.mem.tokenizeScalar(u8, line, ',');
        const col: usize = try std.fmt.parseInt(usize, comma_tokenizer.next() orelse unreachable, 10);
        const row: usize = try std.fmt.parseInt(usize, comma_tokenizer.next() orelse unreachable, 10);

        // std.debug.print("col: {}, row: {}\n", .{ col, row });
        grid.setAt(col, row, '#');
    }
}

fn line_after_count(input: []const u8, count: usize) []const u8 {
    var line_num: usize = 0;
    var line_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (line_tokenizer.next()) |line| : (line_num += 1) {
        if (line_num == count) return line;
    }
    unreachable;
}

fn firstBlock(allocator: Allocator, grid: *Grid, input: []const u8, min_count: usize, max_count: usize) !Position {
    // std.debug.print("Searching between {} and {}\n", .{ min_count, max_count });
    if (max_count - min_count <= 1) {
        const line = line_after_count(input, min_count);
        var comma_tokenizer = std.mem.tokenizeScalar(u8, line, ',');
        const col: usize = try std.fmt.parseInt(usize, comma_tokenizer.next() orelse unreachable, 10);
        const row: usize = try std.fmt.parseInt(usize, comma_tokenizer.next() orelse unreachable, 10);

        return Position{ .col = col, .row = row };
    }

    grid.clearAll('#');
    const mid = min_count + ((max_count - min_count) / 2);
    try setup(grid, input, mid);

    const start = Position{ .col = 0, .row = 0 };
    const end = Position{ .col = grid.size - 1, .row = grid.size - 1 };

    _ = Traversal.shortestDistance(grid, start, end, allocator) catch |err| {
        if (err == TraversalError.NoPath) {
            return firstBlock(allocator, grid, input, min_count, mid);
        } else {
            unreachable;
        }
    };

    return firstBlock(allocator, grid, input, mid, max_count);
}

fn count_char(data: []const u8, value: u8) usize {
    var count: usize = 0;
    for (data) |byte| {
        if (byte == value) count += 1;
    }
    return count;
}

const INPUT = @embedFile("inputs/day18.txt");
pub fn main() !void {
    const MIN_COUNT = 1024;
    const SIZE = 71;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var grid = try Grid.init(allocator, SIZE);
    defer grid.deinit();

    const MAX_COUNT = count_char(INPUT, '\n') + 1;

    const pos = try firstBlock(allocator, &grid, INPUT, MIN_COUNT, MAX_COUNT);
    std.debug.print("Result: {},{}\n", .{ pos.col, pos.row });
}

test "sample input: setup + shortest_distance" {
    const allocator = std.testing.allocator;
    var grid = try Grid.init(allocator, 7);
    defer grid.deinit();
    const MAX_COUNT = count_char(SAMPLE_INPUT, '\n') + 1;

    const pos = try firstBlock(allocator, &grid, SAMPLE_INPUT, 12, MAX_COUNT);
    try std.testing.expectEqual(6, pos.col);
    try std.testing.expectEqual(1, pos.row);
}
