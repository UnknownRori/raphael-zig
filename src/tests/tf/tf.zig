const std = @import("std");
const testing = std.testing;

const tf = @import("../../tf.zig");
const ArenaAllocator = std.heap.ArenaAllocator;

test "Should initialize correctly" {
    var arena = ArenaAllocator.init(testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var tf_map = try tf.TermFreq.init(allocator);
    defer tf_map.deinit();

    try testing.expectEqual(0, tf_map.map.count());
}

test "Should split the text correctly" {
    var arena = ArenaAllocator.init(testing.allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const text = "Hello, urmom is nice and I want to say hello to her.";

    var tf_map = try tf.TermFreq.parse(allocator, text);
    defer tf_map.deinit();

    try testing.expectEqual(12, tf_map.map.count());
}
