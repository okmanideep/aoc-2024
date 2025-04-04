const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const NumberList = ArrayList(u3);
const Out = struct {
    list: *NumberList,

    fn init(allocator: Allocator) !Out {
        const list_ptr = try allocator.create(NumberList);
        list_ptr.* = NumberList.init(allocator);
        return Out{ .list = list_ptr };
    }

    fn deinit(self: *Out) void {
        const allocator = self.list.allocator;
        self.list.deinit();
        allocator.destroy(self.list);
    }

    fn write(self: *Out, value: u3) !void {
        try self.list.append(value);
    }

    fn clear(self: *Out) void {
        self.list.clearRetainingCapacity();
    }

    fn print(self: *Out) void {
        for (self.list.items, 0..) |num, i| {
            std.debug.print("{d}", .{num});
            if (i < self.list.items.len - 1) {
                std.debug.print(",", .{});
            }
        }
        std.debug.print("\n", .{});
    }
};

const ADV: u3 = 0;
const BXL: u3 = 1;
const BST: u3 = 2;
const JNZ: u3 = 3;
const BXC: u3 = 4;
const OUT: u3 = 5;
const BDV: u3 = 6;
const CDV: u3 = 7;

const Machine = struct {
    // registers
    a: u64,
    b: u64,
    c: u64,

    fn execute_all(self: *Machine, program: []const u3, out: *Out) !void {
        var ip: usize = 0;
        while (ip + 1 < program.len) {
            const opcode: u3 = program[ip];
            const operand: u3 = program[ip + 1];
            const jump_to = try self.execute(opcode, operand, out);
            if (jump_to < 0) {
                ip += 2;
            } else {
                ip = @intCast(jump_to);
            }
        }
    }

    fn expectOut(self: *Machine, program: []const u3, out: *Out, expected: []u3) !bool {
        var ip: usize = 0;
        while (ip + 1 < program.len) {
            const opcode: u3 = program[ip];
            const operand: u3 = program[ip + 1];
            const jump_to = try self.execute(opcode, operand, out);
            if (jump_to < 0) {
                ip += 2;
            } else {
                ip = @intCast(jump_to);
            }

            if (!std.mem.eql(u3, out.list.items, expected[0..out.list.items.len])) return false;
        }

        return std.mem.eql(u3, expected, out.list.items);
    }

    fn execute(self: *Machine, opcode: u3, operand: u3, out: *Out) !isize {
        var jump_to: isize = -1;
        switch (opcode) {
            ADV => {
                self.a = self.div(self.combo(operand));
            },
            BXL => {
                self.b = self.b ^ @as(u64, @intCast(operand));
            },
            BST => {
                self.b = self.combo(operand) % 8;
            },
            JNZ => {
                if (self.a != 0) {
                    jump_to = @intCast(operand);
                }
            },
            BXC => {
                self.b = self.b ^ self.c;
            },
            OUT => {
                const out_value: u3 = @intCast(self.combo(operand) % 8);
                try out.write(out_value);
            },
            BDV => {
                self.b = self.div(self.combo(operand));
            },
            CDV => {
                self.c = self.div(self.combo(operand));
            },
        }
        return jump_to;
    }

    inline fn div(self: *Machine, operand: u64) u64 {
        if (operand > std.math.maxInt(u6)) return 0;

        const operand_as_u6: u6 = @intCast(operand);
        return self.a >> operand_as_u6;
    }

    inline fn combo(self: *Machine, operand: u3) u64 {
        if (operand < 4) {
            return @intCast(operand);
        } else if (operand == 4) {
            return self.a;
        } else if (operand == 5) {
            return self.b;
        } else if (operand == 6) {
            return self.c;
        } else {
            unreachable;
        }
    }
};

inline fn parseProgram(program_as_text: []const u8) []u3 {
    var backing_array: [20]u3 = undefined;
    var len: usize = 0;

    var tokenizer = std.mem.tokenizeScalar(u8, program_as_text, ',');
    while (tokenizer.next()) |char| : (len += 1) {
        backing_array[len] = std.fmt.parseInt(u3, char, 10) catch unreachable;
    }

    return backing_array[0..len];
}

fn find_A(machine: *Machine, out: *Out, input: []const u8) !u64 {
    var lines_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    var index: usize = 0;
    var a: u64 = 0;
    while (lines_tokenizer.next()) |line| : (index += 1) {
        if (index == 0) {
            // std.debug.print("Register A: {s}\n", .{line[12..line.len]});
            machine.a = std.fmt.parseInt(u64, line[12..line.len], 10) catch unreachable;
        } else if (index == 1) {
            // std.debug.print("Register B: {s}\n", .{line[12..line.len]});
            machine.b = std.fmt.parseInt(u64, line[12..line.len], 10) catch unreachable;
        } else if (index == 2) {
            // std.debug.print("Register C: {s}\n", .{line[12..line.len]});
            machine.c = std.fmt.parseInt(u64, line[12..line.len], 10) catch unreachable;
        } else if (index == 3) {
            const PG_START = 9;
            const program_as_text = line[PG_START..];
            const program = parseProgram(program_as_text);
            std.debug.print("Program: {s}\n", .{program_as_text});

            var program_index = program.len - 2;
            while (program_index >= 0) : (a = a << 3) {
                const max = a + std.math.pow(u64, 2, program.len - program_index + 10);
                const expected: []u3 = program[program_index..];
                while (a < max) : (a += 1) {
                    machine.a = a;
                    out.clear();

                    if (try machine.expectOut(program, out, expected)) break;
                }

                std.debug.print("a: {d}:0o{o}\n", .{ a, a });

                if (a >= max) unreachable;

                if (program_index > 0) {
                    program_index -= 1;
                } else {
                    break;
                }
            }
            machine.a = a;
            out.clear();
            try machine.execute_all(program, out);
            std.debug.assert(std.mem.eql(u3, program, out.list.items));
        } else {
            unreachable;
        }
    }

    return a;
}

const INPUT = @embedFile("inputs/day17.txt");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var out = try Out.init(allocator);
    defer out.deinit();

    var machine = Machine{ .a = 0, .b = 0, .c = 0 };
    // 2,4,1,3,7,5,1,5,0,3,4,1,5,5,3,0
    // 2, 4 => b = a % 8;
    // 1, 3 => b = b ^ 3;
    // 7, 5 => c = a >> b;
    // 1, 5 => b = b ^ b; => b = 0;
    // 0, 3 => a = a >> 3;
    // 4, 1 => b = b ^ c; => b = c;
    // 5, 5 => out(b % 8); => out(c % 8) => out((a >> ((a % 8) ^ 3) % 8))

    const result = try find_A(&machine, &out, INPUT);

    out.clear();

    machine.a = result;
    const program_as_text = "2,4,1,3,7,5,1,5,0,3,4,1,5,5,3,0";
    const program = parseProgram(program_as_text);
    try machine.execute_all(program, &out);
    std.debug.assert(std.mem.eql(u3, program, out.list.items));

    std.debug.print("Result: {d}\n", .{result});
}

test "sample input reproduces itself for 117440" {
    const sample_input =
        \\Register A: 2024
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,3,5,4,3,0
    ;

    const allocator = std.testing.allocator;
    var out = try Out.init(allocator);
    defer out.deinit();

    var machine = Machine{ .a = 0, .b = 0, .c = 0 };

    const result = try find_A(&machine, &out, sample_input);

    try std.testing.expectEqual(117440, result);
}
