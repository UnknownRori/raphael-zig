const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const Value = @import("./value.zig").Value;
const Lexer = @import("./lexer.zig").Lexer;
const Token = @import("./token.zig").Token;
const TokenType = @import("./token.zig").TokenType;

pub const Error = error{
    UnexpectedToken,
};

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    pos: usize,

    const Self = @This();

    pub fn init(allocator: Allocator, data: []const u8) !Self {
        var lexer = Lexer.init(data);
        var tokens = std.ArrayList(Token).init(allocator);
        while (lexer.next()) |token| {
            try tokens.append(token);
        }

        return Self{
            .tokens = tokens,
            .pos = 0,
        };
    }

    fn is_empty(self: *Self) bool {
        return self.pos >= self.tokens.items.len;
    }

    fn advance(self: *Self) void {
        self.pos += 1;
    }

    fn current(self: *Self) ?Token {
        if (self.is_empty()) return null;
        return self.tokens.items[self.pos];
    }

    fn peek_next(self: *Self) ?Token {
        if (self.pos + 1 >= self.tokens.items.len) return null;
        return self.tokens.items[self.pos + 1];
    }

    fn check(self: *Self, expected: Token) bool {
        if (self.current() == null) return false;
        return expected.equals(self.current().?);
    }

    fn consume(self: *Self, expected: Token) Error!void {
        if (self.check(expected)) {
            self.advance();
        } else {
            return error.UnexpectedToken;
        }
    }

    fn get_multiple_value(self: *Self, allocator: Allocator) !std.ArrayList(u8) {
        var str = std.ArrayList(u8).init(allocator);
        while (!self.is_empty()) {
            const tok = self.current() orelse return Error.UnexpectedToken;
            if (tok.equals(TokenType.EndLine)) {
                break;
            }

            switch (tok) {
                .Indent => |n| {
                    try str.appendNTimes(' ', n);
                },
                .Value => |n| {
                    try str.appendSlice(n);
                },
                else => return Error.UnexpectedToken,
            }
            self.advance();
        }
        return str;
    }

    pub fn parse(self: *Self, allocator: Allocator) !std.ArrayList(Value) {
        var values = std.ArrayList(Value).init(allocator);
        var indent: u32 = 0;
        while (!self.is_empty()) {
            const tok = self.current() orelse return Error.UnexpectedToken;
            std.debug.print("{any}\n", .{tok});
            switch (tok) {
                .Indent => |n| indent = n,
                .Value => |n| {
                    std.debug.print("{s}\n", .{n});
                    try values.append(try self.parse_value(allocator, indent));
                },
                .EndLine => {
                    self.advance();
                },
                else => return Error.UnexpectedToken,
            }
        }
        return values;
    }

    fn parse_value(self: *Self, allocator: Allocator, indent: u32) !Value {
        _ = indent; // Verify the current indent
        const tok = self.current() orelse return Error.UnexpectedToken;
        const key = tok.getValue() orelse return Error.UnexpectedToken;

        var key_str = try std.ArrayList(u8).initCapacity(allocator, key.len);
        try key_str.appendSlice(key);
        errdefer key_str.deinit();

        self.advance();
        try self.consume(TokenType.Colon);

        const curr_tok = self.current() orelse return Error.UnexpectedToken;
        switch (curr_tok) {
            .Indent => {
                self.advance();
                const val = try self.get_multiple_value(allocator);

                return Value{ .Scalar = .{
                    .key = key_str,
                    .value = val,
                } };
            },
            .EndLine => {
                self.advance();
                const token = self.current() orelse return Error.UnexpectedToken;
                switch (token) {
                    .Indent => |n| {
                        const sequence = try self.parse_sequence(allocator, n);
                        return Value{ .Sequence = .{
                            .key = key_str,
                            .value = sequence,
                        } };
                    },
                    else => return Error.UnexpectedToken,
                }
            },
            else => return Error.UnexpectedToken,
        }

        return Error.UnexpectedToken;
    }

    fn parse_sequence(self: *Self, allocator: Allocator, indent: u32) !std.ArrayList(std.ArrayList(u8)) {
        var sequence = std.ArrayList(std.ArrayList(u8)).init(allocator);
        errdefer sequence.deinit();

        while (!self.is_empty()) {
            const tok2 = self.current();
            std.debug.print("{any}", .{self.current()});
            switch (tok2.?) {
                .Value => |n| std.debug.print("{s}", .{n}),
                else => {},
            }
            try self.consume(Token{ .Indent = indent });
            try self.consume(TokenType.Dash);
            try self.consume(Token{ .Indent = 1 });

            const tok = self.current() orelse return Error.UnexpectedToken;
            switch (tok) {
                .Value => {
                    const val = try self.get_multiple_value(allocator);
                    try sequence.append(val);
                    self.advance();
                },
                else => return Error.UnexpectedToken,
            }
        }

        return sequence;
    }
    fn parse_mapping(self: *Parser, indent: u32) !Value {
        _ = self;
        _ = indent;
        return Error.UnexpectedToken;
    }

    pub fn deinit(self: Self) void {
        self.tokens.deinit();
    }
};

test "Parse simple scalar value" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const data = "name: Agustina";

    var parser = try Parser.init(allocator, data);
    defer parser.deinit();

    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();
    const value = try parser.parse(arena.allocator());
    defer value.deinit();

    try testing.expectEqual(1, value.items.len);
    try testing.expectEqualStrings("Agustina", value.items[0].Scalar.value.items);
    try testing.expectEqualStrings("name", value.items[0].Scalar.key.items);
}

test "Parse simple sequence value" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const data = "names:\n  - Agustine\n  - Haruka";

    var parser = try Parser.init(allocator, data);
    defer parser.deinit();

    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();
    const value = try parser.parse(arena.allocator());
    defer value.deinit();

    try testing.expectEqual(1, value.items.len);
    try testing.expectEqualStrings("names", value.items[0].Sequence.key.items);
    try testing.expectEqual(2, value.items[0].Sequence.value.items.len);
    try testing.expectEqualStrings("Agustine", value.items[0].Sequence.value.items[0].items);
    try testing.expectEqualStrings("Haruka", value.items[0].Sequence.value.items[1].items);
}

test "Parse combined value" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const data = "description: Agusta Nana\nnames:\n  - Agustine\n  - Haruka";

    var parser = try Parser.init(allocator, data);
    defer parser.deinit();

    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();
    const value = try parser.parse(arena.allocator());
    defer value.deinit();

    try testing.expectEqual(2, value.items.len);
    switch (value.items[0]) {
        .Scalar => |scalar| {
            try testing.expectEqualStrings("description", scalar.key.items);
            try testing.expectEqualStrings("Agusta Nana", scalar.value.items);
        },
        else => try testing.expect(false),
    }

    switch (value.items[1]) {
        .Sequence => |seq| {
            try testing.expectEqual(2, seq.value.items.len);
            try testing.expectEqualStrings("names", seq.key.items);
            try testing.expectEqualStrings("Agustine", seq.value.items[0].items);
            try testing.expectEqualStrings("Haruka", seq.value.items[1].items);
        },
        else => try testing.expect(false),
    }
}
