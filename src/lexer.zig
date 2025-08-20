const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Lexer = struct {
    allocator: Allocator,
    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn parse(self: Self, contents: []const u8) Allocator.Error!std.StringHashMap(u32) {
        var tf = std.StringHashMap(u32).init(self.allocator);

        var lines_sequence = std.mem.tokenizeSequence(u8, contents, "\n");
        while (lines_sequence.next()) |line| {
            var line_sequence = std.mem.tokenizeSequence(u8, line, " ");
            while (line_sequence.next()) |word| {
                const trimmed = std.mem.trim(u8, word, "\"");

                if (tf.contains(trimmed)) {
                    const a = tf.getEntry(trimmed).?;
                    a.value_ptr.* += @as(u32, 1);
                    continue;
                }
                _ = try tf.getOrPutValue(trimmed, 1);
            }
        }
        return tf;
    }
};
