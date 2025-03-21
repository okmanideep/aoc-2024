const std = @import("std");
const ArrayList = std.ArrayList;
const INPUT = @embedFile("inputs/day9.txt");

const Block = union(enum) { file_id: usize, none };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    var memory = ArrayList(Block).init(allocator);
    defer memory.deinit();

    try expand(&memory, INPUT[0..]);
    compact(memory.items);
    const result = checksum(memory.items);

    try std.io.getStdOut().writer().print("Result: {d}\n", .{result});
}

fn expand(out: *ArrayList(Block), disk_map: []const u8) !void {
    var id: usize = 0;
    var index: usize = 0;

    while (index < disk_map.len) : (index += 1) {
        if (disk_map[index] == '\n') return;

        const digit = std.fmt.parseInt(u8, disk_map[index .. index + 1], 10) catch |err| {
            if (err == std.fmt.ParseIntError.InvalidCharacter) {
                try std.io.getStdOut().writer().print("Invalid Character : `{s}`\n", .{disk_map[index .. index + 1]});
            }
            unreachable;
        };
        if (index % 2 == 0) {
            for (0..digit) |_| {
                // digit = number of blocks
                try out.append(Block{ .file_id = id });
            }
            id += 1;
        } else {
            for (0..digit) |_| {
                // digit = number of spaces
                try out.append(.none);
            }
        }
    }
}

fn checksum(memory: []Block) u64 {
    var result: u64 = 0;
    var index: u64 = 0;
    while (index < memory.len) : (index += 1) {
        switch (memory[index]) {
            .none => return result,
            .file_id => |*file_id| result += file_id.* * index,
        }
    }

    return result;
}

fn compact(memory: []Block) void {
    if (memory.len <= 1) return;

    var front: usize = 0;
    var back: usize = memory.len - 1;

    while (front < memory.len and back > front) {
        if (memory[front] == .none and memory[back] == .file_id) {
            // swap
            const temp = memory[front];
            memory[front] = memory[back];
            memory[back] = temp;
        } else {
            if (memory[front] != .none) {
                front += 1;
            }

            if (memory[back] == .none) {
                back -= 1;
            }
        }
    }
}

test "aoc example" {
    const allocator = std.testing.allocator;

    const input_1 = "2333133121414131402";
    const expected = 1928;
    var memory_1 = ArrayList(Block).init(allocator);
    defer memory_1.deinit();
    try expand(&memory_1, input_1);
    compact(memory_1.items);
    const result = checksum(memory_1.items);
    try std.testing.expectEqual(expected, result);
}
