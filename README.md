# permutation

A permutation library for zig.

## Flavors

Comptime:

```zig
var p = comptime_permutations([_]u8{ 'a', 'b', 'c' });
try std.testing.expectEqual([6][3]u8, @TypeOf(p));
try std.testing.expectEqual(p, [_][3]u8{ "abc".*, "bac".*, "cab".*, "acb".*, "bca".*, "cba".* });
```

Static:

```zig
var p = StaticPermutations(u8, 3).init("abc");
try std.testing.expectEqual([6][3]u8, @TypeOf(p.permutations));
try std.testing.expectEqual(p.permutations, [_][3]u8{ "abc".*, "bac".*, "cab".*, "acb".*, "bca".*, "cba".* });
p.set("xyz");
try std.testing.expectEqual(p.permutations, [_][3]u8{ "xyz".*, "yxz".*, "zxy".*, "xzy".*, "yzx".*, "zyx".* });
```

Dynamic:

```zig
var p = try DynamicPermutations(u8, .{ .outer_is_const = true, .inner_is_const = true }).init(std.testing.allocator, "abc");
defer p.deinit();
try std.testing.expectEqual([]const []const u8, @TypeOf(p.permutations));
const expect = [_][]const u8{ "abc", "bac", "cab", "acb", "bca", "cba" };
for (0..p.permutations.len) |i| try std.testing.expectEqualSlices(u8, expect[i], p.permutations[i]);

```