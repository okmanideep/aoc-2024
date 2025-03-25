const std = @import("std");
const ArrayList = std.ArrayList;
const INPUT = @embedFile("inputs/day13.txt");

const TEST_INPUT = @embedFile("inputs/day13-test.txt");

fn min(first: usize, second: usize) usize {
    if (first < second) {
        return first;
    } else {
        return second;
    }
}

fn max(first: usize, second: usize) usize {
    if (first > second) {
        return first;
    } else {
        return second;
    }
}

const ClawMachine = struct {
    ax: usize,
    ay: usize,
    bx: usize,
    by: usize,
    px: usize,
    py: usize,

    fn leastTokensForPrize(self: ClawMachine) usize {
        // two equations here
        // ac = count of A button pushes
        // bc = count of B button pushes
        //
        // ac * ax + bc * bx = px
        // ac * ay + bc * by = py
        //
        // what is the least ac*3 + bc

        const ax = self.ax;
        const ay = self.ay;
        const bx = self.bx;
        const by = self.by;
        const px = self.px;
        const py = self.py;

        const max_ac = min(px / ax, py / ay);
        const max_bc = min(px / bx, py / by);

        var min_tokens: usize = std.math.maxInt(usize);

        var ac: usize = 0;
        while (ac <= max_ac) : (ac += 1) {
            var bc: usize = 0;
            while (bc <= max_bc) : (bc += 1) {
                if ((ac * ax + bc * bx == px) and (ac * ay + bc * by == py)) {
                    const tokens = 3 * ac + bc;
                    min_tokens = min(min_tokens, tokens);
                }
            }
        }

        if (min_tokens == std.math.maxInt(usize)) return 0;
        return min_tokens;
    }

    fn leastTokensForPrizeOptimal(self: ClawMachine) usize {
        // two equations here
        // ac = count of A button pushes
        // bc = count of B button pushes
        //
        // ac * ax + bc * bx = px
        // ac * ay + bc * by = py
        //
        // what is the least ac*3 + bc

        const ax = self.ax;
        const ay = self.ay;
        const bx = self.bx;
        const by = self.by;
        const px = self.px;
        const py = self.py;

        const max_ac = min(px / ax, py / ay);

        var low: usize = 0;
        var high: usize = max_ac;
        while (high - low > 1) {
            const ac = low + (high - low) / 2;

            if ((px - ac * ax) * by == (py - ac * ay) * bx) break;

            if (((px - low * ax) * by > (py - low * ay) * bx) != ((px - ac * ax) * by > (py - ac * ay) * bx) and
                ((px - high * ax) * by > (py - high * ay) * bx) == ((px - ac * ax) * by > (py - ac * ay) * bx))
            {
                // solution is towards low
                high = ac;
                continue;
            } else if (((px - low * ax) * by > (py - low * ay) * bx) == ((px - ac * ax) * by > (py - ac * ay) * bx) and
                ((px - high * ax) * by > (py - high * ay) * bx) != ((px - ac * ax) * by > (py - ac * ay) * bx))
            {
                // solution is towards high
                low = ac;
                continue;
            } else {
                // no solution
                return 0;
            }
        }

        const ac = low + ((high - low) / 2);
        const bc = (px - ac * ax) / bx;
        if ((ac * ax + bc * bx == px) and (ac * ay + bc * by == py)) {
            return 3 * ac + bc;
        } else {
            return 0;
        }
    }
};

fn parseClawMachine(lines: [3][]const u8) !ClawMachine {
    // Button A: X+ax, Y+ay
    const ax = try std.fmt.parseInt(usize, lines[0][12..14], 10);
    const ay = try std.fmt.parseInt(usize, lines[0][18..20], 10);

    // Button B: X+bx, Y+by
    const bx = try std.fmt.parseInt(usize, lines[1][12..14], 10);
    const by = try std.fmt.parseInt(usize, lines[1][18..20], 10);

    var prizeTokenizer = std.mem.tokenizeAny(u8, lines[2], "Prize: X=,Y\r\n");
    const px_as_string = prizeTokenizer.next() orelse unreachable;
    const px = try std.fmt.parseInt(usize, px_as_string, 10);
    const py_as_string = prizeTokenizer.next() orelse unreachable;
    const py = try std.fmt.parseInt(usize, py_as_string, 10);

    return ClawMachine{ .ax = ax, .ay = ay, .bx = bx, .by = by, .px = px, .py = py };
}

fn parseClawMachineList(out: *ArrayList(ClawMachine), input: []const u8) !void {
    var lines_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines_tokenizer.next()) |first_line| {
        var lines: [3][]const u8 = undefined;
        lines[0] = first_line;
        lines[1] = lines_tokenizer.next() orelse unreachable;
        lines[2] = lines_tokenizer.next() orelse unreachable;

        try out.append(try parseClawMachine(lines));
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("MEMORY LEAK");
    }

    var list = ArrayList(ClawMachine).init(allocator);
    defer list.deinit();

    try parseClawMachineList(&list, INPUT[0..]);

    var result: u64 = 0;
    for (list.items) |cm| {
        result += cm.leastTokensForPrize();
    }

    try std.io.getStdOut().writer().print("Result: {d}\n", .{result});
}

test "parseClawMachine" {
    const btn_a_line_1 = "Button A: X+94, Y+34\n";
    const btn_b_line_1 = "Button B: X+22, Y+67\n";
    const prize_line_1 = "Prize: X=8400, Y=5400\n";

    const lines = [_][]const u8{ btn_a_line_1, btn_b_line_1, prize_line_1 };
    const claw_machine_1 = try parseClawMachine(lines);
    try std.testing.expectEqualDeep(ClawMachine{ .ax = 94, .ay = 34, .bx = 22, .by = 67, .px = 8400, .py = 5400 }, claw_machine_1);
}

test "aoc example" {
    const allocator = std.testing.allocator;
    var list = ArrayList(ClawMachine).init(allocator);
    defer list.deinit();

    try parseClawMachineList(&list, TEST_INPUT[0..]);
    try std.testing.expectEqual(4, list.items.len);
    try std.testing.expectEqualDeep(ClawMachine{ .ax = 94, .ay = 34, .bx = 22, .by = 67, .px = 8400, .py = 5400 }, list.items[0]);

    try std.testing.expectEqual(280, list.items[0].leastTokensForPrizeOptimal());
    try std.testing.expectEqual(0, list.items[1].leastTokensForPrizeOptimal());
    try std.testing.expectEqual(200, list.items[2].leastTokensForPrizeOptimal());
    try std.testing.expectEqual(0, list.items[3].leastTokensForPrizeOptimal());
}
