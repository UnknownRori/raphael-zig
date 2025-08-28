const std = @import("std");
const os = @import("builtin").os;

const TokenType = @import("./token.zig").TokenType;
const Token = @import("./token.zig").Token;

fn ChopWhileFunction(comptime ctx: anytype) type {
    return comptime fn (@TypeOf(ctx), char: u8) bool;
}

pub const Lexer = struct {
    contents: []const u8,
    const Self = @This();

    pub fn init(contents: []const u8) Self {
        return Self{
            .contents = contents,
        };
    }

    fn skip_indent(self: *Self) u32 {
        var whitespace: u32 = 0;
        while (self.contents.len > 0 and self.contents[0] == ' ') {
            whitespace += 1;
            self.contents = self.contents[1..];
        }
        return whitespace;
    }

    fn skip_endline(self: *Self) bool {
        if (self.contents[0] == '\r' and self.contents[1] == '\n') {
            _ = self.chop(2);
            return true;
        } else if (self.contents[0] == '\n') {
            _ = self.chop(1);
            return true;
        }
        return false;
    }

    pub fn chop_while(self: *Self, ctx: anytype, function: ChopWhileFunction(ctx)) []const u8 {
        var n: usize = 0;

        while (n < self.contents.len and function(ctx, self.contents[n])) {
            n += 1;
        }

        return self.chop(n);
    }

    pub fn chop(self: *Self, n: usize) []const u8 {
        const token = self.contents[0..n];
        self.contents = self.contents[n..];
        return token;
    }

    pub fn next(self: *Self) ?Token {
        if (self.contents.len == 0) {
            return null;
        }

        if (self.skip_endline()) {
            return TokenType.EndLine;
        }

        const indent = self.skip_indent();
        if (indent > 0) {
            return Token{ .Indent = indent };
        }

        if (self.contents[0] == ':') {
            _ = self.chop(1);
            return TokenType.Colon;
        }

        if (self.contents[0] == '-') {
            _ = self.chop(1);
            return TokenType.Dash;
        }

        if (std.ascii.isAlphanumeric(self.contents[0])) {
            const chop_alphanum = struct {
                fn chop(ctx: anytype, char: u8) bool {
                    _ = ctx;
                    return std.ascii.isAlphanumeric(char) or char == '-' or char == '/' or char == ',' or char == '\'' or char == '.' or char == '!' or char == '?';
                }
            };

            const value = self.chop_while(chop_alphanum, chop_alphanum.chop);
            return Token{ .Value = value };
        }

        return null;
    }
};

test "Lexer correctly count indentation" {
    const testing = std.testing;

    const data = "  ";
    var lexer = Lexer.init(data);
    const token = lexer.next().?;
    switch (token) {
        .Indent => |n| try testing.expectEqual(2, n),
        else => try testing.expect(false),
    }
}

test "Lexer correctly get value" {
    const testing = std.testing;

    const data = "lorem";
    var lexer = Lexer.init(data);
    const token = lexer.next().?;
    switch (token) {
        .Value => |n| try testing.expectEqualStrings("lorem", n),
        else => try testing.expect(false),
    }
}

test "Lexer correctly scalar" {
    const testing = std.testing;

    const data = "lorem: nyam";
    var lexer = Lexer.init(data);
    const token = lexer.next().?;
    switch (token) {
        .Value => |n| try testing.expectEqualStrings("lorem", n),
        else => try testing.expect(false),
    }

    const token2 = lexer.next().?;
    switch (token2) {
        .Colon => try testing.expect(true),
        else => try testing.expect(false),
    }

    const token3 = lexer.next().?;
    switch (token3) {
        .Indent => |n| try testing.expectEqual(1, n),
        else => try testing.expect(false),
    }

    const token4 = lexer.next().?;
    switch (token4) {
        .Value => |n| try testing.expectEqualStrings("nyam", n),
        else => try testing.expect(false),
    }
}

test "Lexer correctly sequence" {
    const testing = std.testing;

    const data = "lorem:\n  - Haruka\n  - Hanamaru";
    const expected_array: []const Token = &.{
        Token{ .Value = "lorem" },
        TokenType.Colon,
        TokenType.EndLine,
        Token{ .Indent = 2 },
        TokenType.Dash,
        Token{ .Indent = 1 },
        Token{ .Value = "Haruka" },
        TokenType.EndLine,
        Token{ .Indent = 2 },
        TokenType.Dash,
        Token{ .Indent = 1 },
        Token{ .Value = "Hanamaru" },
    };

    var lexer = Lexer.init(data);
    var i: usize = 0;
    while (lexer.next()) |token| {
        const expected = expected_array[i];
        try testing.expect(std.meta.activeTag(expected) == std.meta.activeTag(token));
        i += 1;
    }

    try testing.expectEqual(expected_array.len, i);
}

test "Lexer correctly sequence with windows endline" {
    const testing = std.testing;

    const data = "lorem:\r\n  - Haruka\r\n  - Hanamaru";
    const expected_array: []const Token = &.{
        Token{ .Value = "lorem" },
        TokenType.Colon,
        TokenType.EndLine,
        Token{ .Indent = 2 },
        TokenType.Dash,
        Token{ .Indent = 1 },
        Token{ .Value = "Haruka" },
        TokenType.EndLine,
        Token{ .Indent = 2 },
        TokenType.Dash,
        Token{ .Indent = 1 },
        Token{ .Value = "Hanamaru" },
    };

    var lexer = Lexer.init(data);
    var i: usize = 0;
    while (lexer.next()) |token| {
        const expected = expected_array[i];
        try testing.expect(std.meta.activeTag(expected) == std.meta.activeTag(token));
        i += 1;
    }

    try testing.expectEqual(expected_array.len, i);
}
