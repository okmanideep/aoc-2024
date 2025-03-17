const std = @import("std");
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const INPUT = @embedFile("inputs/day5.txt");

const NodeMap = AutoHashMap(u8, *Node);

pub fn main() !void {
    const result = try sumOfMiddlesToBePrinted(INPUT);
    try std.io.getStdOut().writer().print("Result: {}\n", .{result});
}

const Node = struct {
    value: u8,
    dependencies: *ArrayList(u8),
};

fn deinitNodeMap(map: *NodeMap) void {
    var it = map.iterator();
    while (it.next()) |entry| {
        const node = entry.value_ptr.*;
        node.dependencies.*.deinit();
        map.allocator.destroy(node.dependencies);
        map.allocator.destroy(node);
    }

    map.deinit();
}

fn populateDependencies(map: *NodeMap, data: []const u8) !void {
    var linesTokenizer = std.mem.tokenizeScalar(u8, data, '\n');
    while (linesTokenizer.next()) |line| {
        if (line.len < 5 or line[2] != '|') {
            break;
        }

        // try std.io.getStdOut().writer().print("Processing Dependency: {s}\n", .{line});

        const dependencyValue = try std.fmt.parseInt(u8, line[0..2], 10);
        const nodeValue = try std.fmt.parseInt(u8, line[3..5], 10);
        if (!map.contains(nodeValue)) {
            const dependencies = try map.allocator.create(ArrayList(u8));
            dependencies.* = ArrayList(u8).init(map.allocator);
            const node = try map.allocator.create(Node);
            node.* = Node{ .dependencies = dependencies, .value = nodeValue };
            try map.put(nodeValue, node);
        } else {}
        var node_ptr = map.get(nodeValue) orelse unreachable;

        try node_ptr.dependencies.append(dependencyValue);
    }
}

fn contains_in_list(list: *ArrayList(u8), value: u8) bool {
    return contains(list.items, value);
}

fn contains(slice: []u8, value: u8) bool {
    for (slice) |item| {
        if (item == value) {
            return true;
        }
    }
    return false;
}

fn sumOfMiddlesToBePrinted(data: []const u8) !u32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    var map = NodeMap.init(allocator);
    defer deinitNodeMap(&map);

    try populateDependencies(&map, data);

    var lines_tokenizer = std.mem.splitScalar(u8, data, '\n');

    var skipped_lines_count: usize = 0;
    while (lines_tokenizer.next()) |line| {
        skipped_lines_count += 1;
        if (line.len < 5) break;
    }
    // reached page numbers to be printed
    // try std.io.getStdOut().writer().print("Skipped Lines: {d}\n", .{skipped_lines_count});

    var result: u32 = 0;
    var count: u32 = 0;
    while (lines_tokenizer.next()) |line| : (count += 1) {
        // try std.io.getStdOut().writer().print("Evaluating Line: {s}\n", .{line});
        if (line.len <= 1) continue;

        // if (count > 5) break;
        var printable = true;
        var pn_tokenizer = std.mem.tokenizeScalar(u8, line[0 .. line.len - 1], ',');

        var page_numbers = ArrayList(u8).init(allocator);
        defer page_numbers.deinit();
        while (pn_tokenizer.next()) |page_number_as_string| {
            const page_number = try std.fmt.parseInt(u8, page_number_as_string, 10);

            try page_numbers.append(page_number);
        }

        // for (page_numbers.items) |item| {
        //     try std.io.getStdOut().writer().print("{d},", .{item});
        // }
        // try std.io.getStdOut().writer().print("\n", .{});

        outer: for (page_numbers.items, 0..) |item, index| {
            if (!map.contains(item)) {
                continue;
            }

            const node = map.get(item) orelse unreachable;
            const dependencies = node.dependencies.items;
            // print item -> dependency,dependency,...
            // try std.io.getStdOut().writer().print("{d} -> ", .{item});
            // for (dependencies) |dependency| {
            //     try std.io.getStdOut().writer().print("{d},", .{dependency});
            // }
            // try std.io.getStdOut().writer().print("\n", .{});

            for (dependencies) |dependency| {
                if (contains(page_numbers.items, dependency) and !contains(page_numbers.items[0 .. index + 1], dependency)) {
                    // try std.io.getStdOut().writer().print("Unprintable because: {d}|{d}\n", .{ dependency, node.value });
                    printable = false;
                    break :outer;
                } else {
                    // const dependency_exists = contains(page_numbers.items, dependency);
                    // const dependency_exists_before = contains(page_numbers.items[0 .. index + 1], dependency);
                    // if (!dependency_exists) {
                    //     try std.io.getStdOut().writer().print("Printable because: {d} does not exist\n", .{dependency});
                    // } else if (dependency_exists_before) {
                    //     try std.io.getStdOut().writer().print("Printable because: {d} appears before {d}\n", .{ dependency, item });
                    // }
                }
            }
        }

        if (printable) {
            const middle = page_numbers.items[page_numbers.items.len / 2];
            // try std.io.getStdOut().writer().print("Middle - '{d}' for Line {s}\n", .{ middle, line });
            result += middle;
        } else {
            // try std.io.getStdOut().writer().print("Unprintable Line: {s}\n", .{line});
        }
    }

    return result;
}

const TEST_INPUT = @embedFile("inputs/day5-test.txt");

test "aoc example" {
    const result = try sumOfMiddlesToBePrinted(TEST_INPUT);
    try std.testing.expectEqual(143, result);
}

test "check dependency population" {
    const allocator = std.testing.allocator;

    var map = NodeMap.init(allocator);
    defer deinitNodeMap(&map);

    try populateDependencies(&map, TEST_INPUT);

    const node_47: *Node = map.get(47) orelse unreachable;
    try std.testing.expectEqual(true, contains_in_list(node_47.dependencies, 97));
    try std.testing.expectEqual(true, contains_in_list(node_47.dependencies, 75));
    try std.testing.expectEqual(false, contains_in_list(node_47.dependencies, 53));
    try std.testing.expectEqual(false, contains_in_list(node_47.dependencies, 13));
    try std.testing.expectEqual(false, contains_in_list(node_47.dependencies, 61));
    try std.testing.expectEqual(false, contains_in_list(node_47.dependencies, 29));
}
