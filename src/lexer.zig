const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
fn ChopWhileFunction(comptime ctx: anytype) type {
    return comptime fn (@TypeOf(ctx), char: u8) bool;
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

    pub fn chop(self: *Self, n: usize) []const u8 {
        const token = self.contents[0..n];
        self.contents = self.contents[n..];
        return token;
    }

    pub fn chop_while(self: *Self, ctx: anytype, function: ChopWhileFunction(ctx)) []const u8 {
        var n: usize = 0;

        while (n < self.contents.len and function(ctx, self.contents[n])) {
            n += 1;
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
                fn chop(ctx: anytype, char: u8) bool {
                    _ = ctx;
                    return std.ascii.isDigit(char);
                }
            };

            return self.chop_while(chop_while_struct, chop_while_struct.chop);
        }

        if (std.ascii.isAlphabetic(self.contents[0])) {
            const chop_while_struct = struct {
                fn chop(ctx: anytype, char: u8) bool {
                    _ = ctx;
                    return std.ascii.isAlphanumeric(char);
                }
            };

            return self.chop_while(chop_while_struct, chop_while_struct.chop);
        }

        return self.chop(1);
    }

    pub fn next(self: *Self) ?[]const u8 {
        return self.next_token();
    }
};
