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
    loop: while (index < memory.len) : (index += 1) {
        switch (memory[index]) {
            .none => continue :loop,
            .file_id => |*file_id| result += file_id.* * index,
        }
    }

    return result;
}

fn swapIfPossible(space: []Block, file: []Block) bool {
    var space_len: usize = 0;
    var file_len: usize = 0;

    // print(space, "Space: ") catch unreachable;
    // print(file, "File : ") catch unreachable;

    const file_id = file[0].file_id;

    while (space_len < space.len) : (space_len += 1) {
        if (space[space_len] != .none) {
            break;
        }
    }

    while (file_len < file.len) : (file_len += 1) {
        if (file[file_len] != .file_id or file[file_len].file_id != file_id) {
            break;
        }
    }

    // const stdio = std.io.getStdOut().writer();
    // stdio.print("Space: {}, File: {}\n", .{ space_len, file_len }) catch unreachable;

    if (space_len < file_len) return false;

    var index: usize = 0;
    while (index < file_len) : (index += 1) {
        const temp = space[index];
        space[index] = file[index];
        file[index] = temp;
    }

    return true;
}

fn compact(memory: []Block) void {
    if (memory.len <= 1) return;

    var front: usize = 0;
    var back: usize = memory.len - 1;

    while (front < memory.len and back > 0) {
        if (memory[front] == .none and memory[back] == .file_id and (memory[back - 1] == .none or memory[back - 1].file_id != memory[back].file_id)) {
            const swapped = swapIfPossible(memory[front..], memory[back..]);
            if (swapped) {
                // continue to the next file from back
                // and start over to look for space from front
                back -= 1;
                front = 0;
            } else {
                // look for bigger space from front
                front += 1;
                if (front >= back) {
                    // continue to the next file from back
                    // and start over to look for space from front
                    back -= 1;
                    front = 0;
                }
            }
        } else {
            if (memory[front] != .none) {
                front += 1;
                if (front >= back) {
                    // continue to the next file from back
                    // and start over to look for space from front
                    back -= 1;
                    front = 0;
                }
            }

            if (memory[back] == .none) {
                back -= 1;
            } else if (memory[back] == .file_id and memory[back - 1] == .file_id and memory[back].file_id == memory[back - 1].file_id) {
                back -= 1;
            }
        }
    }
}

fn print(memory: []Block, comptime prefix: []const u8) !void {
    const stdio = std.io.getStdOut().writer();
    try stdio.print(prefix, .{});
    for (memory) |block| {
        if (block == .none) {
            try stdio.print(".", .{});
        } else {
            try stdio.print("{d}", .{block.file_id});
        }
    }
    try stdio.print("\n", .{});
}

test "aoc example" {
    const allocator = std.testing.allocator;

    const input_1 = "2333133121414131402";
    const expected = 2858;
    var memory_1 = ArrayList(Block).init(allocator);
    defer memory_1.deinit();
    try expand(&memory_1, input_1);
    // try print(memory_1.items, "");
    compact(memory_1.items);
    // try print(memory_1.items, "");
    const result = checksum(memory_1.items);
    try std.testing.expectEqual(expected, result);
}
