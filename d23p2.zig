const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const ByteList = std.ArrayList(u8);

const Node = struct {
    name: []const u8,
    connections: *ByteList,
    allocator: Allocator,

    fn init(allocator: Allocator, name: []const u8) !Node {
        const connections_ptr = try allocator.create(ByteList);
        connections_ptr.* = ByteList.init(allocator);

        return Node{ .name = name, .connections = connections_ptr, .allocator = allocator };
    }

    fn deinit(self: *Node) void {
        self.connections.deinit();
        self.allocator.destroy(self.connections);
    }

    fn addConnection(self: *Node, other_node_name: []const u8) !void {
        std.debug.assert(other_node_name.len == 2);
        try self.connections.appendSlice(other_node_name);
    }

    fn isConnectedTo(self: *Node, other_node_name: []const u8) bool {
        return isPresentInConns(self.connections.items, other_node_name);
    }
};

const NodeMap = std.StringArrayHashMap(*Node);

fn isPresentInConns(conns: []const u8, name: []const u8) bool {
    std.debug.assert(name.len == 2);
    std.debug.assert(conns.len % 2 == 0);
    const num_conns = conns.len / 2;
    for (0..num_conns) |i| {
        const conn_name = conns[i * 2 .. i * 2 + 2];
        if (std.mem.eql(u8, conn_name, name)) return true;
    }

    return false;
}

const ConnSet = std.StringHashMap(void);
fn buildSet(set: *ConnSet, conns: []const u8) !void {
    const count = conns.len / 2;
    for (0..count) |i| {
        try set.put(conns[2 * i .. 2 * i + 2], {});
    }
}

fn commonConnections(arena: *ArenaAllocator, first_conns: []const u8, second_conns: []const u8) ![]const u8 {
    const allocator = arena.allocator();
    var out = ByteList.init(allocator);
    var set: ConnSet = ConnSet.init(arena.child_allocator);
    defer set.deinit();

    var conns = first_conns;
    if (first_conns.len > second_conns.len) {
        const size: u32 = @intCast(second_conns.len / 2);
        try set.ensureTotalCapacity(size);
        try buildSet(&set, second_conns);
        conns = first_conns;
    } else {
        conns = second_conns;
        const size: u32 = @intCast(first_conns.len / 2);
        try set.ensureTotalCapacity(size);
        try buildSet(&set, first_conns);
    }

    const count = conns.len / 2;
    for (0..count) |i| {
        const conn_name = conns[i * 2 .. i * 2 + 2];
        if (set.contains(conn_name)) {
            try out.appendSlice(conn_name);
        }
    }

    return out.items;
}

fn isLess(left: []const u8, right: []const u8) bool {
    if (left[0] > right[0]) return false;
    if (left[0] < right[0]) return true;

    return left[1] < right[1];
}

fn binarySearch(sorted_conns: []const u8, name: []const u8) usize {
    const conns_count = sorted_conns.len / 2;
    var start: usize = 0;
    var end: usize = conns_count;

    while (end - start > 1) {
        const mid = start + ((end - start) / 2);
        const conn_name = sorted_conns[2 * mid .. 2 * mid + 2];
        if (isLess(conn_name, name)) {
            start = mid;
        } else {
            end = mid;
        }
    }

    const conn_name = sorted_conns[2 * start .. 2 * start + 2];
    if (isLess(conn_name, name)) {
        return start + 1;
    } else {
        return start;
    }
}

fn insertInConns(arena: *ArenaAllocator, sorted_conns: []const u8, name: []const u8) ![]const u8 {
    const allocator = arena.allocator();
    var out = try ByteList.initCapacity(allocator, sorted_conns.len + name.len);

    const index = binarySearch(sorted_conns, name);
    try out.appendSlice(sorted_conns[0 .. 2 * index]);
    try out.appendSlice(name);
    try out.appendSlice(sorted_conns[2 * index ..]);

    return out.items;
}

fn debugPrintConns(conns: []const u8) void {
    std.debug.assert(conns.len % 2 == 0);

    const count = conns.len / 2;
    for (0..count) |i| {
        std.debug.print("{s}", .{conns[2 * i .. 2 * i + 2]});
        if (i < count - 1) {
            std.debug.print(",", .{});
        }
    }

    std.debug.print("\n", .{});
}

fn max(first: usize, second: usize) usize {
    if (first > second) return first;
    return second;
}

const LargestPartyCache = std.StringHashMap([]const u8);

const Graph = struct {
    node_map: *NodeMap,
    allocator: Allocator,

    fn init(allocator: Allocator, network: []const u8) !Graph {
        const map_ptr = try allocator.create(NodeMap);
        map_ptr.* = NodeMap.init(allocator);

        var tokenizer = std.mem.tokenizeScalar(u8, network, '\n');
        while (tokenizer.next()) |conn_as_string| {
            const first_node_name = conn_as_string[0..2];
            const second_node_name = conn_as_string[3..5];

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

    fn getLanPartyCount(self: *Graph) usize {
        var count: usize = 0;

        const keys = self.node_map.keys();
        for (0..keys.len) |i| {
            const first_conn_name = keys[i];
            const first_conn_node = self.node_map.get(first_conn_name) orelse unreachable;
            for (i + 1..keys.len) |j| {
                const second_conn_name = keys[j];
                if (!first_conn_node.isConnectedTo(second_conn_name)) continue;

                const second_conn_node = self.node_map.get(second_conn_name) orelse unreachable;

                for (j + 1..keys.len) |k| {
                    const third_conn_name = keys[k];
                    if (first_conn_node.isConnectedTo(third_conn_name) and second_conn_node.isConnectedTo(third_conn_name)) {
                        if (first_conn_name[0] == 't' or second_conn_name[0] == 't' or third_conn_name[0] == 't') {
                            count += 1;
                        }
                    }
                }
            }
        }

        return count;
    }

    fn largestLanPartyWith(self: *Graph, arena: *ArenaAllocator, cache: *LargestPartyCache, members: []const u8, potential_members: []const u8, min_conns: usize) ![]const u8 {
        std.debug.assert(members.len % 2 == 0);
        std.debug.assert(potential_members.len % 2 == 0);
        if (potential_members.len == 0) return members;
        if (cache.get(members)) |value| {
            return value;
        }

        // std.debug.print("members: {s}, potential_members: {s}\n", .{members, potential_members});
        if (potential_members.len == 2) return try insertInConns(arena, members, potential_members);

        var largest_party = members;
        const potential_member_count = potential_members.len / 2;
        for (0..potential_member_count) |i| {
            const potential_member_name = potential_members[2 * i .. 2 * i + 2];
            const potential_member = self.node_map.get(potential_member_name) orelse unreachable;

            const remaining_potential_members = try commonConnections(arena, potential_members, potential_member.connections.items);
            if ((members.len / 2) + (remaining_potential_members.len / 2) + 1 < min_conns) {
                continue;
            }
            const new_members = try insertInConns(arena, members, potential_member_name);

            const party = try self.largestLanPartyWith(arena, cache, new_members, remaining_potential_members, max(min_conns, largest_party.len / 2));
            if (party.len > largest_party.len) {
                largest_party = party;
            }
        }

        try cache.put(members, largest_party);

        return largest_party;
    }

    fn getLargestLanParty(self: *Graph, arena: *ArenaAllocator) ![]const u8 {
        var largest_party: []const u8 = "";
        var cache = LargestPartyCache.init(arena.allocator());

        var iterator = self.node_map.iterator();
        while (iterator.next()) |entry| {
            const name = entry.key_ptr.*;
            const node = entry.value_ptr.*;
            const party = try self.largestLanPartyWith(arena, &cache, name, node.connections.items, largest_party.len / 2);
            if (party.len > largest_party.len) {
                largest_party = party;
            }
        }

        return largest_party;
    }
};

const INPUT = @embedFile("inputs/day23.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var graph = try Graph.init(allocator, INPUT);
    defer graph.deinit();

    std.debug.print("Number of nodes: {}\n", .{graph.node_map.keys().len});

    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    const largest_party = try graph.getLargestLanParty(&arena);
    debugPrintConns(largest_party);
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

    try std.testing.expectEqualSlices(u8, "tcqp", graph.node_map.get("kh").?.connections.items);
    try std.testing.expectEqualSlices(u8, "kh", graph.node_map.get("tc").?.connections.items);
    try std.testing.expectEqualSlices(u8, "kh", graph.node_map.get("qp").?.connections.items);
    try std.testing.expectEqualSlices(u8, "cg", graph.node_map.get("de").?.connections.items);
    try std.testing.expectEqualSlices(u8, "de", graph.node_map.get("cg").?.connections.items);
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

    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    try std.testing.expectEqualSlices(u8, "codekata", try graph.getLargestLanParty(&arena));
}
