const std = @import("std");

pub const TokenType = enum {
    Indent,
    Dash,
    Colon,
    Value,
    EndLine,
};
pub const Token = union(TokenType) {
    Indent: u32,
    Dash,
    Colon,
    Value: []const u8,
    EndLine,

    pub fn equals(self: Token, other: Token) bool {
        return std.meta.eql(self, other);
    }

    pub fn getValue(self: Token) ?[]const u8 {
        switch (self) {
            .Value => |n| return n,
            else => return null,
        }
    }
};
