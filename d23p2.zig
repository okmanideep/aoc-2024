const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const ByteList = std.ArrayList(u8);
const IntList = std.ArrayList(u16);

const Node = struct {
    name: u16,
    connections: *IntSet,
    allocator: Allocator,

    fn init(allocator: Allocator, name: u16) !Node {
        const connections_ptr = try allocator.create(IntSet);
        connections_ptr.* = try IntSet.init(allocator);

        return Node{ .name = name, .connections = connections_ptr, .allocator = allocator };
    }

    fn deinit(self: *Node) void {
        self.connections.deinit();
        self.allocator.destroy(self.connections);
    }

    fn addConnection(self: *Node, other_node_name: u16) !void {
        try self.connections.append(other_node_name);
    }

    fn connectionsAsString(self: *Node, out: *ByteList) !void {
        for (self.connections.values()) |item| {
            var bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &bytes, item, .big);
            try out.appendSlice(bytes[0..]);
        }
    }
};

const IntVoidMap = std.AutoArrayHashMap(u16, void);
const IntersectionOptions = struct {
    out: *IntSet,
    without: ?*const IntSet,
};
const IntSet = struct {
    backing_map: *IntVoidMap,
    allocator: Allocator,

    fn init(allocator: Allocator) !IntSet {
        const map_ptr = try allocator.create(IntVoidMap);
        map_ptr.* = IntVoidMap.init(allocator);

        return IntSet{ .backing_map = map_ptr, .allocator = allocator };
    }

    fn initWithSlice(allocator: Allocator, slice: []u16) !IntSet {
        var set = try IntSet.init(allocator);
        try set.backing_map.ensureTotalCapacity(slice.len);

        for (slice) |item| {
            try set.append(item);
        }

        return set;
    }

    fn cloneWithAllocator(self: *const IntSet, allocator: Allocator) !IntSet {
        const map_ptr = try allocator.create(IntVoidMap);
        map_ptr.* = try self.backing_map.cloneWithAllocator(allocator);

        return IntSet{ .backing_map = map_ptr, .allocator = allocator };
    }

    fn deinit(self: *IntSet) void {
        self.backing_map.deinit();
        self.allocator.destroy(self.backing_map);
    }

    fn values(self: *const IntSet) []u16 {
        return self.backing_map.keys();
    }

    fn last(self: *const IntSet) u16 {
        const items = self.values();
        return items[items.len - 1];
    }

    fn len(self: *const IntSet) usize {
        return self.backing_map.keys().len;
    }

    fn intersection(self: *const IntSet, other: *const IntSet, options: IntersectionOptions) !void {
        var list = self;
        var set = other;

        if (other.len() < self.len()) {
            list = other;
            set = self;
        }

        const out = options.out;
        const without = options.without;

        for (list.values()) |value| {
            if (set.contains(value)) {
                if (without) |wo| {
                    if (!wo.contains(value)) {
                        try out.append(value);
                    }
                } else {
                    try out.append(value);
                }
            }
        }
    }

    fn contains(self: *const IntSet, value: u16) bool {
        return self.backing_map.contains(value);
    }

    fn append(self: *IntSet, value: u16) !void {
        try self.backing_map.put(value, {});
    }
};

const SortedIntList = struct {
    backing_list: *IntList,
    allocator: Allocator,

    fn init(allocator: Allocator) !SortedIntList {
        const list_ptr = try allocator.create(IntList);
        list_ptr.* = IntList.init(allocator);
        std.debug.assert(list_ptr.items.len == 0);
        return SortedIntList{ .backing_list = list_ptr, .allocator = allocator };
    }

    fn initSingle(allocator: Allocator, value: u16) !SortedIntList {
        const list_ptr = try allocator.create(IntList);
        list_ptr.* = try IntList.initCapacity(allocator, 1);
        try list_ptr.append(value);

        std.debug.assert(list_ptr.items.len == 1);
        return SortedIntList{ .backing_list = list_ptr, .allocator = allocator };
    }

    fn deinit(self: *SortedIntList) void {
        self.backing_list.deinit();
        self.allocator.destroy(self.backing_list);
    }

    fn copyFrom(self: *SortedIntList, other: *const SortedIntList) !void {
        try self.backing_list.appendSlice(other.backing_list.items);
    }

    fn cloneWithAllocator(self: *const SortedIntList, allocator: Allocator) !SortedIntList {
        const list_ptr = try allocator.create(IntList);
        list_ptr.* = try IntList.initCapacity(allocator, self.backing_list.items.len);
        list_ptr.appendSliceAssumeCapacity(self.backing_list.items);

        return SortedIntList{ .backing_list = list_ptr, .allocator = allocator };
    }

    fn len(self: *const SortedIntList) usize {
        return self.backing_list.items.len;
    }

    fn at(self: *const SortedIntList, index: usize) u16 {
        return self.backing_list.items[index];
    }

    fn indexToAddAt(self: *const SortedIntList, value: u16) usize {
        var start: usize = 0;
        var end: usize = self.backing_list.items.len;

        while (end > start + 1) {
            const mid = start + ((end - start) / 2);
            if (self.at(mid) < value) {
                start = mid;
            } else {
                end = mid;
            }
        }

        if (self.at(start) < value) {
            return start + 1;
        } else {
            return start;
        }
    }

    fn append(self: *SortedIntList, value: u16) !void {
        const index_to_add = self.indexToAddAt(value);
        try self.backing_list.insert(index_to_add, value);
    }

    fn values(self: *const SortedIntList) []const u16 {
        return self.backing_list.items;
    }

    fn asString(self: *const SortedIntList, out: *ByteList) !void {
        const length = self.backing_list.items.len;
        for (self.backing_list.items, 0..) |item, i| {
            var bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &bytes, item, .big);
            try out.appendSlice(bytes[0..]);

            if (i < length - 1) {
                try out.append(',');
            }
        }
    }
};

const NodeMap = std.AutoArrayHashMap(u16, *Node);

const Graph = struct {
    node_map: *NodeMap,
    allocator: Allocator,

    fn init(allocator: Allocator, network: []const u8) !Graph {
        const map_ptr = try allocator.create(NodeMap);
        map_ptr.* = NodeMap.init(allocator);

        var tokenizer = std.mem.tokenizeScalar(u8, network, '\n');
        while (tokenizer.next()) |conn_as_string| {
            const first_node_name_as_string = conn_as_string[0..2];
            const second_node_name_as_string = conn_as_string[3..5];

            const first_node_name = std.mem.readInt(u16, first_node_name_as_string, .big);
            const second_node_name = std.mem.readInt(u16, second_node_name_as_string, .big);

            if (map_ptr.get(first_node_name)) |first_node_ptr| {
                try first_node_ptr.addConnection(second_node_name);
            } else {
                const first_node_ptr = try allocator.create(Node);
                first_node_ptr.* = try Node.init(allocator, first_node_name);
                try first_node_ptr.addConnection(second_node_name);
                try map_ptr.put(first_node_name, first_node_ptr);
            }

            if (map_ptr.get(second_node_name)) |second_node_ptr| {
                try second_node_ptr.addConnection(first_node_name);
            } else {
                const second_node_ptr = try allocator.create(Node);
                second_node_ptr.* = try Node.init(allocator, second_node_name);
                try second_node_ptr.addConnection(first_node_name);
                try map_ptr.put(second_node_name, second_node_ptr);
            }
        }

        return Graph{ .node_map = map_ptr, .allocator = allocator };
    }

    fn deinit(self: *Graph) void {
        var iterator = self.node_map.iterator();
        while (iterator.next()) |entry| {
            const node_ptr = entry.value_ptr.*;
            node_ptr.deinit();
            self.allocator.destroy(node_ptr);
        }

        self.node_map.deinit();
        self.allocator.destroy(self.node_map);
    }

    fn connectionsAsString(self: *Graph, out: *ByteList, name_as_string: *const [2]u8) !void {
        const name = std.mem.readInt(u16, name_as_string, .big);
        const node = self.node_map.get(name) orelse unreachable;
        try node.connectionsAsString(out);
    }

    fn largestParty(self: *Graph, arena: *ArenaAllocator, out: *SortedIntList, members: *const SortedIntList, potential_members: *const IntSet, without: *const IntSet) !void {
        if (potential_members.len() == 0) {
            try out.copyFrom(members);
            return;
        }

        const allocator = arena.allocator();
        var largest_party = try members.cloneWithAllocator(allocator);

        // last because we know that potential_members are sorted by their degree
        // and most connected pivot allows for most optimisation by skipping most
        // iterations
        const pivot = potential_members.last();
        const pivot_node = self.node_map.get(pivot) orelse unreachable;
        const pivot_connections = pivot_node.connections;

        var completed = try without.cloneWithAllocator(allocator);
        for (potential_members.values()) |item| {
            if (pivot_connections.contains(item)) {
                // skip because we will get to them via the pivot
                // optimisation by arriving at a clique only via one way and all the
                // members of the clique
                continue;
            }

            var new_members = try members.cloneWithAllocator(allocator);
            try new_members.append(item);
            const node = self.node_map.get(item) orelse unreachable;

            var remaining_potential_members = try IntSet.init(allocator);
            try potential_members.intersection(node.connections, .{ .out = &remaining_potential_members, .without = &completed });

            var party = try SortedIntList.init(allocator);

            try self.largestParty(arena, &party, &new_members, &remaining_potential_members, &completed);
            if (party.len() > largest_party.len()) {
                largest_party = try party.cloneWithAllocator(allocator);
            }

            try completed.append(item);
        }

        try out.copyFrom(&largest_party);
    }

    fn getLargestParty(self: *Graph, out: *SortedIntList) !void {
        var largest_party = try SortedIntList.init(self.allocator);

        var arena = ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const arena_allocator = arena.allocator();


        var completed = try IntSet.init(self.allocator);
        defer completed.deinit();
        var iterator = self.node_map.iterator();
        while (iterator.next()) |entry| {
            const name = entry.key_ptr.*;
            const node = entry.value_ptr.*;

            const members = try SortedIntList.initSingle(arena_allocator, name);
            var party = try SortedIntList.init(arena_allocator);
            const connections = try node.connections.cloneWithAllocator(arena_allocator);
            var sorted_connections = try arena_allocator.dupe(u16, connections.values());
            self.sortByConnectionCount(sorted_connections[0..]);
            const potential_members = try IntSet.initWithSlice(arena_allocator, sorted_connections);
            try self.largestParty(&arena, &party, &members, &potential_members, &completed);
            if (party.len() > largest_party.len()) {
                largest_party.deinit();

                largest_party = try party.cloneWithAllocator(self.allocator);
            }

            try completed.append(name);
            _ = arena.reset(.retain_capacity);
        }

        try out.copyFrom(&largest_party);
        largest_party.deinit();
    }

    fn sortByConnectionCount(self: *Graph, names: []u16) void {
        // build max heap
        var i: usize = (names.len / 2) - 1;
        while (i >= 0) {
            self.heapify(names, i);

            if (i > 0) {
                i -= 1;
            } else {
                break;
            }
        }

        var last: usize = names.len - 1;
        while (last > 0) : (last -= 1) {
            const temp = names[last];
            names[last] = names[0];
            names[0] = temp;

            self.heapify(names[0..last], 0);
        }
    }

    fn heapify(self: *Graph, names: []u16, index: usize) void {
        const left = 2 * index + 1;
        const right = 2 * index + 2;

        var largest = index;

        const node = self.node_map.get(names[index]) orelse unreachable;
        const score = node.connections.len();
        if (left < names.len) {
            const left_node = self.node_map.get(names[left]) orelse unreachable;
            const left_score = left_node.connections.len();

            if (left_score > score) {
                largest = left;
            }
        }

        if (right < names.len) {
            const right_node = self.node_map.get(names[right]) orelse unreachable;
            const right_score = right_node.connections.len();

            if (right_score > score) {
                largest = right;
            }
        }

        if (largest != index) {
            self.heapify(names, largest);
        }
    }
};

const INPUT = @embedFile("inputs/day23.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var graph = try Graph.init(allocator, INPUT);
    defer graph.deinit();

    var largest_party = try SortedIntList.init(allocator);
    defer largest_party.deinit();

    var out = ByteList.init(allocator);
    defer out.deinit();

    try graph.getLargestParty(&largest_party);
    try largest_party.asString(&out);
    std.debug.print("Result: {s}\n", .{out.items});
}

test "graph init" {
    const network =
        \\kh-tc
        \\qp-kh
        \\de-cg
    ;

    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, network);
    defer graph.deinit();

    var out = ByteList.init(allocator);
    defer out.deinit();

    try graph.connectionsAsString(&out, "kh");
    try std.testing.expectEqualSlices(u8, "tcqp", out.items);
    out.clearRetainingCapacity();

    try graph.connectionsAsString(&out, "tc");
    try std.testing.expectEqualSlices(u8, "kh", out.items);
    out.clearRetainingCapacity();

    try graph.connectionsAsString(&out, "qp");
    try std.testing.expectEqualSlices(u8, "kh", out.items);
    out.clearRetainingCapacity();

    try graph.connectionsAsString(&out, "de");
    try std.testing.expectEqualSlices(u8, "cg", out.items);
    out.clearRetainingCapacity();

    try graph.connectionsAsString(&out, "cg");
    try std.testing.expectEqualSlices(u8, "de", out.items);
    out.clearRetainingCapacity();

    try std.testing.expectEqual(5, graph.node_map.keys().len);
}

test "aoc example" {
    const network =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    const allocator = std.testing.allocator;
    var graph = try Graph.init(allocator, network);
    defer graph.deinit();

    var largest_party = try SortedIntList.init(allocator);
    defer largest_party.deinit();

    var out = ByteList.init(allocator);
    defer out.deinit();

    try graph.getLargestParty(&largest_party);
    try largest_party.asString(&out);
    try std.testing.expectEqualSlices(u8, "co,de,ka,ta", out.items);
}
