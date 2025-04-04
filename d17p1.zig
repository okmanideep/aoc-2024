// The computer knows eight instructions, each identified by a 3-bit number (called the instruction's opcode). Each instruction also reads the 3-bit number after it as an input; this is called its operand.
//
// A number called the instruction pointer identifies the position in the program from which the next opcode will be read; it starts at 0, pointing at the first 3-bit number in the program. Except for jump instructions, the instruction pointer increases by 2 after each instruction is processed (to move past the instruction's opcode and its operand). If the computer tries to read an opcode past the end of the program, it instead halts.
//
// So, the program 0,1,2,3 would run the instruction whose opcode is 0 and pass it the operand 1, then run the instruction having opcode 2 and pass it the operand 3, then halt.
//
// There are two types of operands; each instruction specifies the type of its operand. The value of a literal operand is the operand itself. For example, the value of the literal operand 7 is the number 7. The value of a combo operand can be found as follows:
//
// Combo operands 0 through 3 represent literal values 0 through 3.
// Combo operand 4 represents the value of register A.
// Combo operand 5 represents the value of register B.
// Combo operand 6 represents the value of register C.
// Combo operand 7 is reserved and will not appear in valid programs.
// The eight instructions are as follows:
//
// The adv instruction (opcode 0) performs division. The numerator is the value in the A register. The denominator is found by raising 2 to the power of the instruction's combo operand. (So, an operand of 2 would divide A by 4 (2^2); an operand of 5 would divide A by 2^B.) The result of the division operation is truncated to an integer and then written to the A register.
//
// The bxl instruction (opcode 1) calculates the bitwise XOR of register B and the instruction's literal operand, then stores the result in register B.
//
// The bst instruction (opcode 2) calculates the value of its combo operand modulo 8 (thereby keeping only its lowest 3 bits), then writes that value to the B register.
//
// The jnz instruction (opcode 3) does nothing if the A register is 0. However, if the A register is not zero, it jumps by setting the instruction pointer to the value of its literal operand; if this instruction jumps, the instruction pointer is not increased by 2 after this instruction.
//
// The bxc instruction (opcode 4) calculates the bitwise XOR of register B and register C, then stores the result in register B. (For legacy reasons, this instruction reads an operand but ignores it.)
//
// The out instruction (opcode 5) calculates the value of its combo operand modulo 8, then outputs that value. (If a program outputs multiple values, they are separated by commas.)
//
// The bdv instruction (opcode 6) works exactly like the adv instruction except that the result is stored in the B register. (The numerator is still read from the A register.)
//
// The cdv instruction (opcode 7) works exactly like the adv instruction except that the result is stored in the C register. (The numerator is still read from the A register.)

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

    fn print(self: *Out) void {
        for (self.list.items, 0..) |num, i| {
            std.debug.print("{d}", .{num});
            if (i < self.list.items.len - 1) {
                std.debug.print(",", .{});
            }
        }
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

// SAMPLE INPUT
// Register A: 729
// Register B: 0
// Register C: 0
//
// Program: 0,1,5,4,3,0
fn run(machine: *Machine, out: *Out, input: []const u8) !void {
    var lines_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    var index: usize = 0;
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
            var pg_index: usize = PG_START;

            while (pg_index < line.len - 2) {
                const opcode: u3 = std.fmt.parseInt(u3, line[pg_index .. pg_index + 1], 10) catch unreachable;
                const operand: u3 = std.fmt.parseInt(u3, line[pg_index + 2 .. pg_index + 3], 10) catch unreachable;
                const jump_to = try machine.execute(opcode, operand, out);
                if (jump_to < 0) {
                    pg_index += 4; // skipping commas as well
                } else {
                    pg_index = PG_START + (@as(usize, @intCast(jump_to)) * 2);
                }
            }
        } else {
            unreachable;
        }
    }
}

const INPUT = @embedFile("inputs/day17.txt");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var out = try Out.init(allocator);
    defer out.deinit();

    var machine = Machine{ .a = 0, .b = 0, .c = 0 };
    try run(&machine, &out, INPUT);

    out.print();
}

test "If register C contains 9, the program 2,6 would set register B to 1." {
    const allocator = std.testing.allocator;
    var out = try Out.init(allocator);
    defer out.deinit();

    const program = [_]u3{ 2, 6 };
    var machine = Machine{ .a = 0, .b = 0, .c = 9 };

    try machine.execute_all(&program, &out);
    try std.testing.expectEqual(machine.b, 1);
}

test "If register A contains 10, the program 5,0,5,1,5,4 would output 0,1,2." {
    const allocator = std.testing.allocator;
    var out = try Out.init(allocator);
    defer out.deinit();

    const program = [_]u3{ 5, 0, 5, 1, 5, 4 };
    var machine = Machine{ .a = 10, .b = 0, .c = 0 };

    try machine.execute_all(&program, &out);

    try std.testing.expectEqualSlices(u3, out.list.items, &[_]u3{ 0, 1, 2 });
}

test "If register A contains 2024, the program 0,1,5,4,3,0 would output 4,2,5,6,7,7,7,7,3,1,0 and leave 0 in register A." {
    const allocator = std.testing.allocator;
    var out = try Out.init(allocator);
    defer out.deinit();

    const program = [_]u3{ 0, 1, 5, 4, 3, 0 };
    var machine = Machine{ .a = 2024, .b = 0, .c = 0 };

    try machine.execute_all(&program, &out);

    try std.testing.expectEqual(machine.a, 0);
    try std.testing.expectEqualSlices(u3, out.list.items, &[_]u3{ 4, 2, 5, 6, 7, 7, 7, 7, 3, 1, 0 });
}

test "If register B contains 29, the program 1,7 would set register B to 26." {
    const allocator = std.testing.allocator;
    var out = try Out.init(allocator);
    defer out.deinit();

    const program = [_]u3{ 1, 7 };
    var machine = Machine{ .a = 0, .b = 29, .c = 0 };

    try machine.execute_all(&program, &out);
    try std.testing.expectEqual(machine.b, 26);
}

test "If register B contains 2024 and register C contains 43690, the program 4,0 would set register B to 44354." {
    const allocator = std.testing.allocator;
    var out = try Out.init(allocator);
    defer out.deinit();

    const program = [_]u3{ 4, 0 };
    var machine = Machine{ .a = 0, .b = 2024, .c = 43690 };

    try machine.execute_all(&program, &out);
    try std.testing.expectEqual(machine.b, 44354);
}

test "sample input's final output will be 4,6,3,5,6,3,5,2,1,0" {
    const sample_input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    const allocator = std.testing.allocator;
    var out = try Out.init(allocator);
    defer out.deinit();

    var machine = Machine{ .a = 0, .b = 0, .c = 0 };
    try run(&machine, &out, sample_input);

    try std.testing.expectEqualSlices(u3, out.list.items, &[_]u3{ 4, 6, 3, 5, 6, 3, 5, 2, 1, 0 });
}
