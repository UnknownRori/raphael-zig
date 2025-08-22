const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const String = std.ArrayList(u8);

const HTTPMethod = @import("./utils.zig").HTTPMethod;

pub const Headers = std.StringHashMap([]const u8);

pub const Request = struct {
    method: HTTPMethod,
    path: []const u8,
    body: []const u8,
    headers: Headers,
    allocator: ArenaAllocator,

    const Self = @This();

    pub fn fromBuffer(parent_allocator: Allocator, buffer: []const u8) !Self {
        var arena = ArenaAllocator.init(parent_allocator);
        const allocator = arena.allocator();
        var split = std.mem.splitSequence(u8, buffer, "\r\n\r\n");

        const header = split.next().?;
        var headerToken = std.mem.splitSequence(u8, header, "\r\n");
        var method: HTTPMethod = .GET;
        var path: []const u8 = "";
        var headers = Headers.init(allocator);

        // TODO : Refactor this
        while (headerToken.next()) |line| {
            if (std.mem.startsWith(u8, line, "GET")) {
                var splitToken = std.mem.splitSequence(u8, line, " ");
                _ = splitToken.next().?;
                path = splitToken.next().?;
                method = .GET;
            } else if (std.mem.startsWith(u8, line, "POST")) {
                var splitToken = std.mem.splitSequence(u8, line, " ");
                _ = splitToken.next().?;
                path = splitToken.next().?;
                method = .POST;
            } else if (std.mem.startsWith(u8, line, "PATCH")) {
                var splitToken = std.mem.splitSequence(u8, line, " ");
                _ = splitToken.next().?;
                path = splitToken.next().?;
                method = .PATCH;
            } else if (std.mem.startsWith(u8, line, "DELETE")) {
                var splitToken = std.mem.splitSequence(u8, line, " ");
                _ = splitToken.next().?;
                path = splitToken.next().?;
                method = .DELETE;
            } else if (std.mem.containsAtLeast(u8, line, 1, ": ")) {
                var splitToken = std.mem.splitSequence(u8, line, ": ");
                const key = splitToken.next();
                const value = splitToken.next();
                if (key == null or value == null) {
                    continue;
                }
                try headers.put(key.?, value.?);
            }
        }

        const body = split.next().?;
        return Self{
            .method = method,
            .path = path,
            .body = body,
            .headers = headers,
            .allocator = arena,
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.deinit();
    }
};
