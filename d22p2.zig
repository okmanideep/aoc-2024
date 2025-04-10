const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

inline fn mix(secret: u64, value: u64) u64 {
    return secret ^ value;
}

const PRUNE_VALUE = std.math.pow(u64, 2, 24);

inline fn prune(secret: u64) u64 {
    return secret % PRUNE_VALUE;
}

fn computeNextSecret(initial_secret: u64) u64 {
    // Calculate the result of multiplying the secret number by 64. Then, mix this result into the secret number. Finally, prune the secret number
    var secret = initial_secret;
    secret = mix(secret, secret << 6);
    secret = prune(secret);
    secret = mix(secret, secret >> 5);
    secret = prune(secret);
    secret = mix(secret, secret << 11);
    secret = prune(secret);
    return secret;
}

fn price(secret: u64) i8 {
    // last digit in decimal representation
    return @as(i8, @intCast(secret % 10));
}

const CacheKey = struct {
    seq: []i8,

    fn hash(self: CacheKey) u32 {
        var hasher = std.hash.Fnv1a_32.init();
        for (self.seq) |num| {
            std.hash.autoHash(&hasher, num);
        }
        return hasher.final();
    }

    fn eql(self: CacheKey, other: CacheKey) bool {
        return std.mem.eql(i8, self.seq, other.seq);
    }
};

const CacheKeyContext = struct {
    pub fn hash(_: CacheKeyContext, key: CacheKey) u32 {
        return key.hash();
    }

    pub fn eql(_: CacheKeyContext, key: CacheKey, other: CacheKey, _: usize) bool {
        return key.eql(other);
    }
};

const PriceCache = std.ArrayHashMap(CacheKey, i8, CacheKeyContext, true);

const Buyer = struct {
    prices: []i8,
    changes: []i8,
    cache: *PriceCache,
    allocator: Allocator,

    fn init(allocator: Allocator, initial_secret: u64, len: u16) !Buyer {
        var prices = try allocator.alloc(i8, len);
        var changes = try allocator.alloc(i8, len);
        var prev_secret = initial_secret;

        for (0..len) |i| {
            const cur_secret = computeNextSecret(prev_secret);
            prices[i] = price(cur_secret);
            changes[i] = prices[i] - if (i > 0) prices[i - 1] else price(prev_secret);

            prev_secret = cur_secret;
        }

        const cache_ptr = try allocator.create(PriceCache);
        cache_ptr.* = PriceCache.init(allocator);
        try cache_ptr.ensureTotalCapacity(len);

        var index: usize = len - 4;
        while (true): (index -= 1) {
            const seq = changes[index..index+4];
            const key = CacheKey{.seq = seq};
            try cache_ptr.put(key, prices[index+3]);

            if (index == 0) break;
        }

        return Buyer{ .prices = prices, .changes = changes, .allocator = allocator, .cache = cache_ptr };
    }

    fn deinit(self: *Buyer) void {
        self.allocator.free(self.prices);
        self.allocator.free(self.changes);
        self.cache.deinit();
        self.allocator.destroy(self.cache);
    }

    fn priceForSequence(self: *Buyer, key: CacheKey) i8 {
        return self.cache.get(key) orelse 0;
    }
};

const BuyerList = ArrayList(*Buyer);

fn deinit_all(allocator: Allocator, list: BuyerList) void {
    for (list.items) |buyer_ptr| {
        buyer_ptr.deinit();
        allocator.destroy(buyer_ptr);
    }
}

const Visited = std.ArrayHashMap(CacheKey, void, CacheKeyContext, true);

fn bananasForSeq(list: BuyerList, key: CacheKey) u64 {
    var count: u64 = 0;
    for (list.items) |buyer| {
        count += @as(u64, @intCast(buyer.priceForSequence(key)));
    }

    return count;
}

const MaxBananasStore = std.ArrayHashMap(CacheKey, u64, CacheKeyContext, true);

fn computeMaxBananas(allocator: Allocator, list: BuyerList) !u64 {
    var visited = Visited.init(allocator);
    defer visited.deinit();

    var store = MaxBananasStore.init(allocator);
    defer store.deinit();

    // build the store
    for (list.items) |buyer| {
        var iterator = buyer.cache.iterator();
        while (iterator.next()) |entry| {
            const key = entry.key_ptr.*;
            const buyer_price = @as(u64, @intCast(entry.value_ptr.*));
            if (store.get(key)) |value| {
                try store.put(key, value + buyer_price);
            } else {
                try store.put(key, buyer_price);
            }
        }
    }

    var max_bananas: u64 = 0;
    var iterator = store.iterator();
    var max_key: CacheKey = undefined;
    while (iterator.next()) |entry| {
        const bananas = entry.value_ptr.*;
        if (bananas > max_bananas) {
            max_bananas = bananas;
            max_key = entry.key_ptr.*;
        }
    }

    // std.debug.print("Sequence: [", .{});
    // for (max_key.seq, 0..) |num, i| {
    //     std.debug.print("{}", .{num});
    //     if (i < max_key.seq.len - 1) {
    //         std.debug.print(",", .{});
    //     }
    // }
    // std.debug.print("]\n", .{});

    // for (list.items) |buyer| {
    //     const bananas = buyer.priceForSequence(max_key);
    //     std.debug.print("{}\n", .{bananas});
    // }

    return max_bananas;
}

fn maxBananas(allocator: Allocator, input: []const u8) !u64 {
    var line_tokenizer = std.mem.tokenizeScalar(u8, input, '\n');

    var list = BuyerList.init(allocator);
    defer list.deinit();

    // std.debug.print("Creating Buyers...\n", .{});
    while (line_tokenizer.next()) |secret_as_string| {
        const initial_secret = try std.fmt.parseInt(u64, secret_as_string, 10);
        const buyer_ptr = try allocator.create(Buyer);
        buyer_ptr.* = try Buyer.init(allocator, initial_secret, COUNT);
        try list.append(buyer_ptr);
    }
    defer deinit_all(allocator, list);
    // std.debug.print("Buyers created\n", .{});

    // std.debug.print("Computing Max Bananas\n", .{});
    const result = try computeMaxBananas(allocator, list);

    return result;
}

const INPUT = @embedFile("inputs/day22.txt");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const result = try maxBananas(allocator, INPUT);

    std.debug.print("Result: {}\n", .{result});
}

const COUNT = 2000;
test "aoc example" {
    const input =
        \\1
        \\2
        \\3
        \\2024
    ;

    try std.testing.expectEqual(23, try maxBananas(std.testing.allocator, input));
}
