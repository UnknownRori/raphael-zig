const std = @import("std");
const testing = std.testing;

fn end_line() []const u8 {
    const os = @import("builtin").os;
    if (os.tag == .windows) {
        return "\r\n";
    } else if (os.tag == .linux) {
        return "\n";
    }
    @panic("Unknown OS");
}

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn parse(self: Self, contents: []const u8) !std.StringHashMap(u32) {
        var tf = std.StringHashMap(u32).init(self.allocator);

        var lines_sequence = std.mem.tokenizeSequence(u8, contents, end_line());
        while (lines_sequence.next()) |line| {
            var line_sequence = std.mem.tokenizeSequence(u8, line, " ");
            while (line_sequence.next()) |word| {
                if (tf.contains(word)) {
                    const a = tf.getEntry(word).?;
                    a.value_ptr.* += @as(u32, 1);
                    continue;
                }
                _ = try tf.getOrPutValue(word, 1);
            }
        }
        return tf;
    }
};
