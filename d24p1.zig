const std = @import("std");
const Allocator = std.mem.Allocator;

const Operation = enum {
    AND,
    OR,
    XOR,
    NONE,

    fn fromChars(oper_chars: []const u8) Operation {
        if (std.mem.eql(u8, "AND", oper_chars)) {
            return Operation.AND;
        } else if (std.mem.eql(u8, "OR", oper_chars)) {
            return Operation.OR;
        } else if (std.mem.eql(u8, "XOR", oper_chars)) {
            return Operation.XOR;
        } else {
            std.debug.print("Trying to parse unknown operation: {s}\n", .{oper_chars});
            unreachable;
        }
    }
};

const Node = struct { name: u32, left: u32, right: u32, oper: Operation };

const Evals = std.AutoHashMap(u32, bool);
const NodeMap = std.AutoHashMap(u32, *Node);

const Wiring = struct {
    nodes: *NodeMap,
    evals: *Evals,
    allocator: Allocator,

    fn init(allocator: Allocator, input: []const u8) !Wiring {
        const nodes_ptr = try allocator.create(NodeMap);
        nodes_ptr.* = NodeMap.init(allocator);

        const evals_ptr = try allocator.create(Evals);
        evals_ptr.* = Evals.init(allocator);

        var lines = std.mem.splitScalar(u8, input, '\n');
        while (lines.next()) |line| {
            if (line.len != 6) break;

            const bytes: [4]u8 = .{ 0, line[0], line[1], line[2] };
            const name = std.mem.readInt(u32, &bytes, .big);
            const node_ptr = try allocator.create(Node);
            node_ptr.* = Node{ .name = name, .left = 0, .right = 0, .oper = .NONE };

            const value = if (line[5] == '1') true else false;

            try nodes_ptr.put(name, node_ptr);
            try evals_ptr.put(name, value);
        }

        while (lines.next()) |line| {
            if (line.len == 0) break;
            var tokenizer = std.mem.tokenizeAny(u8, line, " ->");
            const left_chars = tokenizer.next() orelse unreachable;
            const left_bytes: [4]u8 = .{ 0, left_chars[0], left_chars[1], left_chars[2] };
            const left_name = std.mem.readInt(u32, &left_bytes, .big);

            const oper_chars = tokenizer.next() orelse unreachable;
            const oper = Operation.fromChars(oper_chars);

            const right_chars = tokenizer.next() orelse unreachable;
            const right_bytes: [4]u8 = .{ 0, right_chars[0], right_chars[1], right_chars[2] };
            const right_name = std.mem.readInt(u32, &right_bytes, .big);

            const name_chars = tokenizer.next() orelse unreachable;
            const name_bytes: [4]u8 = .{ 0, name_chars[0], name_chars[1], name_chars[2] };
            const name = std.mem.readInt(u32, &name_bytes, .big);

            const node_ptr = try allocator.create(Node);
            node_ptr.* = Node{ .name = name, .left = left_name, .right = right_name, .oper = oper };

            try nodes_ptr.put(name, node_ptr);
        }

        return Wiring{
            .nodes = nodes_ptr,
            .evals = evals_ptr,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Wiring) void {
        var node_iterator = self.nodes.valueIterator();
        while (node_iterator.next()) |value_ptr| {
            self.allocator.destroy(value_ptr.*);
        }

        self.nodes.deinit();
        self.evals.deinit();
        self.allocator.destroy(self.nodes);
        self.allocator.destroy(self.evals);
    }

    fn eval(self: *Wiring, name: u32) !bool {
        if (self.evals.get(name)) |value| {
            return value;
        } else {
            const node = self.nodes.get(name) orelse unreachable;
            const left_value = try self.eval(node.left);
            const right_value = try self.eval(node.right);

            const value = switch (node.oper) {
                Operation.AND => left_value and right_value,
                Operation.OR => left_value or right_value,
                Operation.XOR => left_value != right_value,
                else => unreachable,
            };

            try self.evals.put(node.name, value);
            return value;
        }
    }

    fn calculateZ(self: *Wiring) !u64 {
        var result: u64 = 0;

        var bit_index: u6 = 0;
        const one_u64: u64 = 1;
        while (bit_index < 64) : (bit_index += 1) {
            const last_digit: u8 = '0' + @as(u8, @intCast(bit_index % 10));
            const tens_digit: u8 = '0' + @as(u8, @intCast((bit_index / 10)));
            const z_name_bytes: [4]u8 = .{ 0, 'z', tens_digit, last_digit };
            const z_name = std.mem.readInt(u32, &z_name_bytes, .big);

            if (self.nodes.contains(z_name)) {
                const set_at_bit_index: u64 = one_u64 << bit_index;
                const is_set = try self.eval(z_name);
                if (is_set) {
                    result = result | set_at_bit_index;
                }
            } else {
                break;
            }
        }

        return result;
    }

    fn getValueOf(self: *Wiring, name_chars: *const [3]u8) !bool {
        const name_bytes: [4]u8 = .{ 0, name_chars[0], name_chars[1], name_chars[2] };
        const name = std.mem.readInt(u32, &name_bytes, .big);
        return self.eval(name);
    }
};

const INPUT = @embedFile("inputs/day24.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var wiring = try Wiring.init(allocator, INPUT);
    defer wiring.deinit();
    const result = try wiring.calculateZ();
    std.debug.print("Result: {}\n", .{result});
}

test "Small example" {
    const input =
        \\x00: 1
        \\x01: 1
        \\x02: 1
        \\y00: 0
        \\y01: 1
        \\y02: 0
        \\
        \\x00 AND y00 -> z00
        \\x01 XOR y01 -> z01
        \\x02 OR y02 -> z02
    ;

    const allocator = std.testing.allocator;
    var wiring = try Wiring.init(allocator, input);
    defer wiring.deinit();

    try std.testing.expectEqual(true, try wiring.getValueOf("x00"));
    try std.testing.expectEqual(true, try wiring.getValueOf("x01"));
    try std.testing.expectEqual(true, try wiring.getValueOf("x02"));
    try std.testing.expectEqual(false, try wiring.getValueOf("y00"));
    try std.testing.expectEqual(true, try wiring.getValueOf("y01"));
    try std.testing.expectEqual(false, try wiring.getValueOf("y02"));
    try std.testing.expectEqual(false, try wiring.getValueOf("z00"));
    try std.testing.expectEqual(false, try wiring.getValueOf("z01"));
    try std.testing.expectEqual(true, try wiring.getValueOf("z02"));

    try std.testing.expectEqual(4, try wiring.calculateZ());
}

test "larger example" {
    const input =
        \\x00: 1
        \\x01: 0
        \\x02: 1
        \\x03: 1
        \\x04: 0
        \\y00: 1
        \\y01: 1
        \\y02: 1
        \\y03: 1
        \\y04: 1
        \\
        \\ntg XOR fgs -> mjb
        \\y02 OR x01 -> tnw
        \\kwq OR kpj -> z05
        \\x00 OR x03 -> fst
        \\tgd XOR rvg -> z01
        \\vdt OR tnw -> bfw
        \\bfw AND frj -> z10
        \\ffh OR nrd -> bqk
        \\y00 AND y03 -> djm
        \\y03 OR y00 -> psh
        \\bqk OR frj -> z08
        \\tnw OR fst -> frj
        \\gnj AND tgd -> z11
        \\bfw XOR mjb -> z00
        \\x03 OR x00 -> vdt
        \\gnj AND wpb -> z02
        \\x04 AND y00 -> kjc
        \\djm OR pbm -> qhw
        \\nrd AND vdt -> hwm
        \\kjc AND fst -> rvg
        \\y04 OR y02 -> fgs
        \\y01 AND x02 -> pbm
        \\ntg OR kjc -> kwq
        \\psh XOR fgs -> tgd
        \\qhw XOR tgd -> z09
        \\pbm OR djm -> kpj
        \\x03 XOR y03 -> ffh
        \\x00 XOR y04 -> ntg
        \\bfw OR bqk -> z06
        \\nrd XOR fgs -> wpb
        \\frj XOR qhw -> z04
        \\bqk OR frj -> z07
        \\y03 OR x01 -> nrd
        \\hwm AND bqk -> z03
        \\tgd XOR rvg -> z12
        \\tnw OR pbm -> gnj
    ;

    const allocator = std.testing.allocator;
    var wiring = try Wiring.init(allocator, input);
    defer wiring.deinit();

    try std.testing.expectEqual(2024, try wiring.calculateZ());
}
