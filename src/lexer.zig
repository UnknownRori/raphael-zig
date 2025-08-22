const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
fn ChopWhileFunction(comptime ctx: anytype) type {
    return comptime fn (@TypeOf(ctx), char: u21) bool;
}

pub const Lexer = struct {
    contents: []const u8,
    const Self = @This();

    pub fn init(contents: []const u8) Self {
        return Self{ .contents = contents };
    }

    pub fn trim_left(self: *Self) void {
        while (self.contents.len > 0 and std.ascii.isWhitespace(self.contents[0])) {
            self.contents = self.contents[1..];
        }
    }

    pub fn chop_codepoint(self: *Lexer) ?[]const u8 {
        if (self.contents.len == 0) return null;

        const seq_len = std.unicode.utf8ByteSequenceLength(self.contents[0]) catch return null;
        if (seq_len > self.contents.len) return null;

        const token = self.contents[0..seq_len];
        _ = std.unicode.utf8Decode(token) catch return null;

        self.contents = self.contents[seq_len..];
        return token;
    }

    pub fn chop(self: *Self, n: usize) []const u8 {
        const token = self.contents[0..n];
        self.contents = self.contents[n..];
        return token;
    }

    pub fn chop_while(self: *Self, ctx: anytype, function: ChopWhileFunction(ctx)) []const u8 {
        var n: usize = 0;

        while (n < self.contents.len) {
            const seq_len = std.unicode.utf8ByteSequenceLength(self.contents[n]) catch break;
            if (n + seq_len > self.contents.len) break;

            const cp = std.unicode.utf8Decode(self.contents[n .. n + seq_len]) catch break;
            if (!function(ctx, cp)) break;

            n += seq_len;
        }

        return self.chop(n);
    }

    pub fn next_token(self: *Self) ?[]const u8 {
        self.trim_left();
        if (self.contents.len == 0) {
            return null;
        }

        if (std.ascii.isDigit(self.contents[0])) {
            const chop_while_struct = struct {
                fn chop(ctx: anytype, char: u21) bool {
                    _ = ctx;
                    if (char > 0x7F) return false;
                    return std.ascii.isDigit(@intCast(char));
                }
            };

            return self.chop_while(chop_while_struct, chop_while_struct.chop);
        }

        if (std.ascii.isAlphabetic(self.contents[0])) {
            const chop_while_struct = struct {
                fn chop(ctx: anytype, char: u21) bool {
                    _ = ctx;
                    if (char > 0x7F) return false;
                    return std.ascii.isAlphanumeric(@intCast(char));
                }
            };

            return self.chop_while(chop_while_struct, chop_while_struct.chop);
        }

        return self.chop_codepoint();
    }

    pub fn next(self: *Self) ?[]const u8 {
        return self.next_token();
    }
};
