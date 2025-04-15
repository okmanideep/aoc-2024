const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const IntVoidMap = std.AutoArrayHashMap(u32, void);
const IntSet = struct {
    backing_map: *IntVoidMap,
    allocator: Allocator,

    fn init(allocator: Allocator) !IntSet {
        const map_ptr = try allocator.create(IntVoidMap);
        map_ptr.* = IntVoidMap.init(allocator);

        return IntSet{ .backing_map = map_ptr, .allocator = allocator };
    }

    fn initWithSlice(allocator: Allocator, slice: []u32) !IntSet {
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

    fn values(self: *const IntSet) []u32 {
        return self.backing_map.keys();
    }

    fn last(self: *const IntSet) u32 {
        const items = self.values();
        return items[items.len - 1];
    }

    fn len(self: *const IntSet) usize {
        return self.backing_map.keys().len;
    }

    fn contains(self: *const IntSet, value: u32) bool {
        return self.backing_map.contains(value);
    }

    fn append(self: *IntSet, value: u32) !void {
        try self.backing_map.put(value, {});
    }
};

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
const Gate = struct { left: u32, right: u32, oper: Operation };

const Evals = std.AutoHashMap(u32, bool);
const NodeMap = std.AutoHashMap(u32, *Node);
const GateMap = std.AutoHashMap(Gate, u32);

const Wiring = struct {
    wires: *Evals, // inputs
    nodes: *NodeMap,
    evals: *Evals,
    gates: *GateMap,
    allocator: Allocator,

    fn init(allocator: Allocator, input: []const u8) !Wiring {
        const nodes_ptr = try allocator.create(NodeMap);
        nodes_ptr.* = NodeMap.init(allocator);

        const evals_ptr = try allocator.create(Evals);
        evals_ptr.* = Evals.init(allocator);

        const wires_ptr = try allocator.create(Evals);
        wires_ptr.* = Evals.init(allocator);

        const gates_ptr = try allocator.create(GateMap);
        gates_ptr.* = GateMap.init(allocator);

        var lines = std.mem.splitScalar(u8, input, '\n');
        while (lines.next()) |line| {
            if (line.len != 6) break;

            const bytes: [4]u8 = .{ 0, line[0], line[1], line[2] };
            const name = std.mem.readInt(u32, &bytes, .big);

            const value = if (line[5] == '1') true else false;

            try wires_ptr.put(name, value);
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

            const gate = Gate{ .left = left_name, .right = right_name, .oper = oper };

            try gates_ptr.put(gate, name);
            try nodes_ptr.put(name, node_ptr);
        }

        return Wiring{
            .nodes = nodes_ptr,
            .evals = evals_ptr,
            .wires = wires_ptr,
            .gates = gates_ptr,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Wiring) void {
        var node_iterator = self.nodes.valueIterator();
        while (node_iterator.next()) |value_ptr| {
            self.allocator.destroy(value_ptr.*);
        }

        self.wires.deinit();
        self.nodes.deinit();
        self.evals.deinit();
        self.gates.deinit();
        self.allocator.destroy(self.wires);
        self.allocator.destroy(self.nodes);
        self.allocator.destroy(self.evals);
        self.allocator.destroy(self.gates);
    }

    fn eval(self: *Wiring, name: u32) !bool {
        if (self.wires.get(name)) |value| {
            return value;
        } else if (self.evals.get(name)) |value| {
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

    fn calculate(self: *Wiring, series: u8) !u64 {
        var result: u64 = 0;

        var bit_index: u6 = 0;
        const one_u64: u64 = 1;
        while (bit_index < 64) : (bit_index += 1) {
            const last_digit: u8 = '0' + @as(u8, @intCast(bit_index % 10));
            const tens_digit: u8 = '0' + @as(u8, @intCast((bit_index / 10)));
            const z_name_bytes: [4]u8 = .{ 0, series, tens_digit, last_digit };
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

    fn calculateZ(self: *Wiring) !u64 {
        return try self.calculate('z');
    }

    fn addConnected(self: *Wiring, out: *IntSet, name: u32) !void {
        const node = self.nodes.get(name) orelse return;
        try out.append(name);
        try self.addConnected(out, node.left);
        try self.addConnected(out, node.right);
    }

    fn findBadOutputs(self: *Wiring, out: *IntSet) !void {
        var bit_index: u6 = 0;
        while (bit_index < 64) : (bit_index += 1) {
            const last_digit: u8 = '0' + @as(u8, @intCast(bit_index % 10));
            const tens_digit: u8 = '0' + @as(u8, @intCast((bit_index / 10)));
            const z_name_bytes: [4]u8 = .{ 0, 'z', tens_digit, last_digit };
            const z_name = std.mem.readInt(u32, &z_name_bytes, .big);
            if (!self.nodes.contains(z_name)) {
                bit_index -= 1;
                break;
            }

            if (bit_index == 63) break;
        }

        const max_bit_index = bit_index;
        bit_index = 0;
        var prev_bits_and_name: u32 = 0;
        var prev_xors_and_name: u32 = 0;
        // z00 = x00 XOR y00; overflow = x00 AND y00
        // z01 = (x01 XOR y01) XOR (overflow); overflow = (cur_and) OR (cur_xor AND overflow)
        // z02 = (x02 XOR y02) XOR (overflow); overflow = (cur_and) OR (cur_xor AND overflow)
        while (bit_index < max_bit_index) : (bit_index += 1) {
            std.debug.print("Bit index: {}\n", .{bit_index});

            const last_digit: u8 = '0' + @as(u8, @intCast(bit_index % 10));
            const tens_digit: u8 = '0' + @as(u8, @intCast((bit_index / 10)));
            const z_name_bytes: [4]u8 = .{ 0, 'z', tens_digit, last_digit };
            const x_name_bytes: [4]u8 = .{ 0, 'x', tens_digit, last_digit };
            const y_name_bytes: [4]u8 = .{ 0, 'y', tens_digit, last_digit };
            const x_name = std.mem.readInt(u32, &x_name_bytes, .big);
            const y_name = std.mem.readInt(u32, &y_name_bytes, .big);
            const z_name = std.mem.readInt(u32, &z_name_bytes, .big);
            const cur_bits_xor_name = self.findGateName(x_name, y_name, .XOR) orelse unreachable;
            const cur_bits_and_name = self.findGateName(x_name, y_name, .AND) orelse unreachable;

            if (prev_bits_and_name == 0 and prev_xors_and_name == 0) {
                if (cur_bits_xor_name != z_name) {
                    std.debug.print("Swap: ", .{});
                    const names: [2]u32 = .{ cur_bits_xor_name, z_name };
                    printNames(names[0..]);
                }
                prev_bits_and_name = cur_bits_and_name;
            } else {
                var overflow_name: u32 = undefined;
                if (prev_xors_and_name == 0) {
                    overflow_name = prev_bits_and_name;
                } else {
                    overflow_name = self.findGateName(prev_bits_and_name, prev_xors_and_name, .OR) orelse unreachable;
                }
                const expected_z_name = self.findGateName(cur_bits_xor_name, overflow_name, .XOR);
                if (expected_z_name == null) {
                    const node = self.nodes.get(z_name) orelse unreachable;
                    const oper = node.oper;
                    var names: [2]u32 = undefined;
                    var cur_overflow: u32 = undefined;
                    if (oper == .XOR and node.left == cur_bits_xor_name) {
                        names[0] = overflow_name;
                        names[1] = node.right;
                        cur_overflow = self.findGateName(cur_bits_xor_name, node.right, .AND) orelse unreachable;
                    } else if (oper == .XOR and node.right == cur_bits_xor_name) {
                        names[0] = overflow_name;
                        names[1] = node.left;
                        cur_overflow = self.findGateName(cur_bits_xor_name, node.left, .AND) orelse unreachable;
                    } else if (oper == .XOR and node.left == overflow_name) {
                        names[0] = cur_bits_xor_name;
                        names[1] = node.right;
                        cur_overflow = self.findGateName(node.right, overflow_name, .AND) orelse unreachable;
                    } else if (oper == .XOR and node.right == overflow_name) {
                        names[0] = cur_bits_xor_name;
                        names[1] = node.left;
                        cur_overflow = self.findGateName(node.left, overflow_name, .AND) orelse unreachable;
                    } else if (oper != .XOR) {
                        try self.addConnected(out, z_name);
                        break;
                    } else {
                        unreachable;
                    }
                    std.debug.print("No Exp Z Swap: ", .{});
                    printNames(names[0..]);
                    prev_bits_and_name = cur_bits_and_name;
                    prev_xors_and_name = cur_overflow;
                } else if (expected_z_name != z_name) {
                    std.debug.print("Swap: ", .{});
                    const names: [2]u32 = .{ expected_z_name.?, z_name };
                    printNames(names[0..]);
                    prev_bits_and_name = cur_bits_and_name;
                    prev_xors_and_name = self.findGateName(cur_bits_xor_name, overflow_name, .AND) orelse unreachable;
                } else {
                    prev_bits_and_name = cur_bits_and_name;
                    prev_xors_and_name = self.findGateName(cur_bits_xor_name, overflow_name, .AND) orelse unreachable;
                }
            }
        }
    }

    fn findGateName(self: *Wiring, left: u32, right: u32, oper: Operation) ?u32 {
        const gate_1 = Gate{ .left = left, .right = right, .oper = oper };
        if (self.gates.get(gate_1)) |value| {
            return value;
        }
        const gate_2 = Gate{ .left = right, .right = left, .oper = oper };
        if (self.gates.get(gate_2)) |value| {
            return value;
        }

        return null;
    }

    fn getValueOf(self: *Wiring, name_chars: *const [3]u8) !bool {
        const name_bytes: [4]u8 = .{ 0, name_chars[0], name_chars[1], name_chars[2] };
        const name = std.mem.readInt(u32, &name_bytes, .big);
        return self.eval(name);
    }
};

fn printNames(names: []const u32) void {
    const length = names.len;
    for (names, 0..) |name, i| {
        var bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &bytes, name, .big);
        std.debug.print("{s}", .{bytes[1..]});

        if (i < length - 1) {
            std.debug.print(",", .{});
        }
    }
    std.debug.print("\n", .{});
}

const INPUT = @embedFile("inputs/day24-corrected.txt");

test "Main" {
    const allocator = std.testing.allocator;

    var wiring = try Wiring.init(allocator, INPUT);
    defer wiring.deinit();
    var out = try IntSet.init(allocator);
    defer out.deinit();

    try wiring.findBadOutputs(&out);
}

