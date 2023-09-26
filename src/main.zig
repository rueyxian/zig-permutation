const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = std.mem.Allocator;

fn generate_static_permutations(comptime T: type, comptime N: usize, items: []const T) [factorial(N)][N]T {
    assert(N == items.len);
    var out: [factorial(N)][N]T = undefined;
    @memcpy(&out[0], items);
    if (N < 2) return out;

    var st = [_]usize{0} ** (N - 1);
    var st_i: usize = st.len - 1;

    var buf: [N]T = undefined;
    @memcpy(&buf, items);

    var out_i: usize = 1;
    while (st_i != std.math.maxInt(usize)) {
        const i = st.len - st_i;
        const k = &st[st_i];
        if (k.* == i) {
            k.* = 0;
            st_i -%= 1;
            continue;
        }
        mem.swap(u8, &buf[if (i % 2 == 0) 0 else k.*], &buf[i]);
        @memcpy(&out[out_i], &buf);
        out_i += 1;
        k.* += 1;
        st_i = st.len - 1;
    }
    return out;
}

pub fn comptime_permutations(comptime items: anytype) switch (comptime_items_info(items)) {
    inline else => |info| [factorial(info.N)][info.N]info.T,
} {
    return switch (comptime_items_info(items)) {
        .array => |info| ComptimePermutations(info.T, info.N).from_array(items),
        .const_slice => |info| ComptimePermutations(info.T, info.N).from_const_slice(items), // `*const [N]T` will be inferred to `[]const T`
    }.factorial;
}

fn ComptimePermutations(comptime T: type, comptime N: usize) type {
    return struct {
        factorial: [factorial(N)][N]T,
        fn from_array(items: [N]T) @This() {
            return @This(){ .factorial = generate_static_permutations(T, N, &items) };
        }
        fn from_const_slice(items: []const T) @This() {
            return @This(){ .factorial = generate_static_permutations(T, N, items) };
        }
    };
}

const ComptimeItemsInfo = union(enum) {
    array: struct { T: type, N: usize },
    const_slice: struct { T: type, N: usize },
};

fn comptime_items_info(comptime items: anytype) ComptimeItemsInfo {
    switch (@typeInfo(@TypeOf(items))) {
        .Array => |info| return ComptimeItemsInfo{ .array = .{ .T = info.child, .N = info.len } },
        .Pointer => |info| switch (info.size) {
            .Slice => return ComptimeItemsInfo{ .const_slice = .{ .T = info.child, .N = items.len } },
            .One => {
                const ptr_info = @typeInfo(info.child);
                if (ptr_info != .Array) @compileError("expect `[N]T` or `*const [N]T` or `[]const T`");
                return ComptimeItemsInfo{ .const_slice = .{ .T = ptr_info.Array.child, .N = ptr_info.Array.len } };
            },
            else => @compileError("expect `[N]T` or `*const [N]T` or `[]const T`"),
        },
        else => @compileError("expect `[N]T` or `*const [N]T` or `[]const T`"),
    }
}

test "comptime permutations" {
    const allocator: Allocator = std.testing.allocator;
    {
        var p = comptime_permutations([0]u8{});
        try test_permutations(u8, 0, .array, allocator, &p);
    }
    {
        var p = comptime_permutations([_]u8{'a'});
        try test_permutations(u8, 1, .array, allocator, &p);
    }
    {
        var p = comptime_permutations([_]u8{ 'a', 'b' });
        try test_permutations(u8, 2, .array, allocator, &p);
    }
    {
        var p = comptime_permutations([_]u8{ 'a', 'b', 'c' });
        try test_permutations(u8, 3, .array, allocator, &p);
    }
    {
        var p = comptime_permutations([_]u8{ 'a', 'b', 'c', 'd' });
        try test_permutations(u8, 4, .array, allocator, &p);
    }
    {
        var p = comptime_permutations([_]u8{ 'a', 'b', 'c', 'd', 'f' });
        try test_permutations(u8, 5, .array, allocator, &p);
    }
    {
        const arr = [_]u8{ 'a', 'b', 'c', 'd', 'f' };
        var p0 = comptime_permutations(@as(*const [5]u8, &arr));
        try test_permutations(u8, 5, .array, allocator, &p0);
        var p1 = comptime_permutations(@as([]const u8, &arr));
        try test_permutations(u8, 5, .array, allocator, &p1);
    }
}

pub fn StaticPermutations(comptime T: type, comptime N: usize) type {
    return struct {
        permutations: [factorial(N)][N]T = undefined,
        const Self = @This();
        fn init_empty() !Self {
            return Self{};
        }
        fn init(items: []const T) Self {
            return Self{ .permutations = generate_static_permutations(T, N, items) };
        }
        fn set(self: *Self, items: []const T) void {
            self.permutations = generate_static_permutations(T, N, items);
        }
    };
}

test "static permutations " {
    const allocator: Allocator = std.testing.allocator;
    {
        var p = StaticPermutations(u8, 0).init(&[_]u8{});
        try test_permutations(u8, 0, .array, allocator, &p.permutations);
    }
    {
        var p = StaticPermutations(u8, 1).init(&[_]u8{'a'});
        try test_permutations(u8, 1, .array, allocator, &p.permutations);
        p.set(&[_]u8{'z'});
        try test_permutations(u8, 1, .array, allocator, &p.permutations);
    }
    {
        var p = StaticPermutations(u8, 2).init(&[_]u8{ 'a', 'b' });
        try test_permutations(u8, 2, .array, allocator, &p.permutations);
        p.set(&[_]u8{ 'z', 'y' });
        try test_permutations(u8, 2, .array, allocator, &p.permutations);
    }
    {
        var p = StaticPermutations(u8, 3).init(&[_]u8{ 'a', 'b', 'c' });
        try test_permutations(u8, 3, .array, allocator, &p.permutations);
        p.set(&[_]u8{ 'z', 'y', 'x' });
        try test_permutations(u8, 3, .array, allocator, &p.permutations);
    }
    {
        var p = StaticPermutations(u8, 4).init(&[_]u8{ 'a', 'b', 'c', 'd' });
        try test_permutations(u8, 4, .array, allocator, &p.permutations);
        p.set(&[_]u8{ 'z', 'y', 'x', 'w' });
        try test_permutations(u8, 4, .array, allocator, &p.permutations);
    }
}

const DynamicSliceOptions = struct {
    outer_is_const: bool = true,
    inner_is_const: bool = true,
    fn Item(comptime self: @This(), comptime T: type) type {
        return if (self.inner_is_const) []const T else []T;
    }
    fn Permutations(comptime self: @This(), comptime T: type) type {
        return if (self.outer_is_const) []const self.Item(T) else []self.Item(T);
    }
};

pub fn DynamicPermutations(comptime T: type, comptime options: DynamicSliceOptions) type {
    return struct {
        permutations: options.Permutations(T),
        allocator: Allocator,
        const Self = @This();

        fn init(allocator: Allocator, items: []const T) !Self {
            const m = try generate_dynamic_permutations(T, options, allocator, items);
            return Self{ .permutations = m, .allocator = allocator };
        }

        fn deinit(self: Self) void {
            for (self.permutations) |slice| self.allocator.free(slice);
            self.allocator.free(self.permutations);
        }
    };
}

fn generate_dynamic_permutations(comptime T: type, comptime options: DynamicSliceOptions, allocator: Allocator, items: []const T) !options.Permutations(T) {
    var out = try allocator.alloc(options.Item(T), factorial(items.len));
    out[0] = try allocator.dupe(T, items);
    if (items.len < 2) return out;

    var st = st: {
        var st = try allocator.alloc(usize, items.len - 1);
        for (st) |*c| c.* = 0;
        break :st st;
    };
    defer allocator.free(st);
    var st_i: usize = st.len - 1;

    var buf = try allocator.dupe(T, items);
    defer allocator.free(buf);

    var out_i: usize = 1;
    while (st_i != std.math.maxInt(usize)) {
        const i = st.len - st_i;
        const k = &st[st_i];
        if (k.* == i) {
            k.* = 0;
            st_i -%= 1;
            continue;
        }
        mem.swap(u8, &buf[if (i % 2 == 0) 0 else k.*], &buf[i]);
        out[out_i] = try allocator.dupe(T, buf);
        out_i += 1;
        k.* += 1;
        st_i = st.len - 1;
    }
    return out;
}

test "dynamic permutations" {
    const allocator: Allocator = std.testing.allocator;
    {
        var p = try DynamicPermutations(u8, .{}).init(allocator, &[_]u8{});
        defer p.deinit();
        try test_permutations(u8, 0, .slice, allocator, p.permutations);
    }
    {
        var p = try DynamicPermutations(u8, .{}).init(allocator, &[_]u8{'a'});
        defer p.deinit();
        try test_permutations(u8, 1, .slice, allocator, p.permutations);
    }
    {
        var p = try DynamicPermutations(u8, .{}).init(allocator, &[_]u8{ 'a', 'b' });
        defer p.deinit();
        try test_permutations(u8, 2, .slice, allocator, p.permutations);
    }
    {
        var p = try DynamicPermutations(u8, .{}).init(allocator, &[_]u8{ 'a', 'b', 'c' });
        defer p.deinit();
        try test_permutations(u8, 3, .slice, allocator, p.permutations);
    }
    {
        var p = try DynamicPermutations(u8, .{}).init(allocator, &[_]u8{ 'a', 'b', 'c', 'd' });
        defer p.deinit();
        try test_permutations(u8, 4, .slice, allocator, p.permutations);
    }
    {
        var p = try DynamicPermutations(u8, .{}).init(allocator, &[_]u8{ 'a', 'b', 'c', 'd', 'f' });
        defer p.deinit();
        try test_permutations(u8, 5, .slice, allocator, p.permutations);
    }
    {
        var p = try DynamicPermutations(u8, .{}).init(allocator, &[_]u8{});
        defer p.deinit();
        try std.testing.expectEqual([]const []const u8, @TypeOf(p.permutations));
    }
    {
        var p = try DynamicPermutations(u8, .{ .outer_is_const = true, .inner_is_const = true }).init(allocator, &[_]u8{});
        defer p.deinit();
        try std.testing.expectEqual([]const []const u8, @TypeOf(p.permutations));
    }
    {
        var p = try DynamicPermutations(u8, .{ .outer_is_const = false, .inner_is_const = true }).init(allocator, &[_]u8{});
        defer p.deinit();
        try std.testing.expectEqual([][]const u8, @TypeOf(p.permutations));
    }
    {
        var p = try DynamicPermutations(u8, .{ .outer_is_const = true, .inner_is_const = false }).init(allocator, &[_]u8{});
        defer p.deinit();
        try std.testing.expectEqual([]const []u8, @TypeOf(p.permutations));
    }
    {
        var p = try DynamicPermutations(u8, .{ .outer_is_const = false, .inner_is_const = false }).init(allocator, &[_]u8{});
        defer p.deinit();
        try std.testing.expectEqual([][]u8, @TypeOf(p.permutations));
    }
}

fn factorial(n: usize) usize {
    assert(n <= FACTORIALS_MAX_N);
    return FACTORIALS_LOOKUP[n];
}

const FACTORIALS_MAX_N = switch (@sizeOf(usize)) {
    16 => 35,
    8 => 20,
    4 => 13,
    2 => 9,
    1 => 6,
    else => unreachable,
};

const FACTORIALS_LOOKUP = blk: {
    var arr: [FACTORIALS_MAX_N + 1]usize = undefined;
    const _factorial = struct {
        fn f(n: usize) usize {
            if (n == 0 or n == 1) return 1;
            var res: usize = 2;
            for (3..n + 1) |i| res *= i;
            return res;
        }
    }.f;
    for (0..FACTORIALS_MAX_N + 1) |i| arr[i] = _factorial(i);
    break :blk arr;
};

fn test_permutations(
    comptime T: type,
    comptime N: usize,
    comptime item_is: enum { array, slice },
    allocator: Allocator,
    permutations: switch (item_is) {
        .array => []const [N]T,
        .slice => []const []const T,
    },
) !void {
    var hm = std.AutoHashMap([N]T, void).init(allocator);
    defer hm.deinit();
    switch (item_is) {
        .array => {
            for (permutations) |perm| try hm.putNoClobber(perm, {});
        },
        .slice => {
            for (permutations) |perm| {
                try std.testing.expectEqual(N, perm.len);
                try hm.putNoClobber(perm[0..N].*, {});
            }
        },
    }
    try std.testing.expectEqual(factorial(N), hm.count());
}
