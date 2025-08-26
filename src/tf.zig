const std = @import("std");
const testing = std.testing;

const Lexer = @import("./lexer.zig").Lexer;
const read_file = @import("./utils/utils.zig").fs.read_file;

const Allocator = std.mem.Allocator;

/// TODO : Refactor this for separation of concern
pub const TermFreq = struct {
    map: std.StringHashMap(u32),
    allocator: Allocator,
    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .map = std.StringHashMap(u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn parse(allocator: Allocator, contents: []const u8) !Self {
        var tf_map = std.StringHashMap(u32).init(allocator);

        var lexer = Lexer.init(contents);
        while (lexer.next()) |item| {
            const token = try std.ascii.allocUpperString(allocator, item);
            if (tf_map.contains(token)) {
                const entry = tf_map.getEntry(token).?;
                entry.value_ptr.* += @as(u32, 1);
                continue;
            }
            _ = try tf_map.getOrPutValue(token, 1);
        }

        return Self{
            .map = tf_map,
            .allocator = allocator,
        };
    }

    pub fn from(map: std.StringHashMap(u32)) Self {
        return Self{
            .map = map,
            .allocator = map.allocator,
        };
    }

    pub fn print(self: Self) void {
        var it = self.map.iterator();
        while (it.next()) |e| {
            std.debug.print("{s} -> {d}\n", .{ e.key_ptr.*, e.value_ptr.* });
        }
    }

    pub fn serializeJson(self: Self, jw: anytype) !void {
        var tf_iter = self.map.iterator();
        try jw.beginObject();

        while (tf_iter.next()) |e| {
            try jw.objectField(e.key_ptr.*);
            try jw.write(e.value_ptr.*);
        }

        try jw.endObject();
    }

    pub fn sum(self: Self) u32 {
        var weight: u32 = 0;
        var tf_iter = self.map.iterator();
        while (tf_iter.next()) |e| {
            weight += e.value_ptr.*;
        }
        return weight;
    }

    pub fn getOr(self: Self, token: []const u8, default: u32) u32 {
        const value = self.map.get(token);
        if (value == null) return default;
        return value.?;
    }

    pub fn contains(self: Self, token: []const u8) bool {
        const value = self.map.get(token);
        if (value == null) return false;
        return true;
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }
};
