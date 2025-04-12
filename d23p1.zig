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

fn commonConnections(arena: *ArenaAllocator, first_conns: []const u8, second_conns: []const u8) []const u8 {
    const allocator = arena.allocator();
    var out = ByteList.init(allocator);
    std.debug.assert(first_conns.len % 2 == 0);
    std.debug.assert(second_conns.len % 2 == 0);
    const first_conns_count = first_conns.len / 2;
    for (0..first_conns_count) |i| {
        const first_conn_name = first_conns[i*2..i*2+2];
        if (isPresentInConns(second_conns, first_conn_name)) {
            out.appendSlice(first_conn_name);
        }
    }

    return out.items;
}

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
};

const INPUT = @embedFile("inputs/day23.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var graph = try Graph.init(allocator, INPUT);
    defer graph.deinit();

    const result = graph.getLanPartyCount();
    std.debug.print("Result: {}\n", .{result});
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

    try std.testing.expectEqual(7, graph.getLanPartyCount());
}
