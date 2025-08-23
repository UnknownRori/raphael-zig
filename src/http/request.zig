const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

const HTTPMethod = @import("./utils.zig").HTTPMethod;
const Headers = @import("./utils.zig").Headers;
const Params = @import("./utils.zig").Params;

pub const Request = struct {
    method: HTTPMethod,
    path: []const u8,
    body: ?std.ArrayList(u8),
    headers: Headers,
    params: Params,
    allocator: Allocator,

    const Self = @This();

    pub fn parseHeader(allocator: Allocator, buffer: []const u8) !Self {
        var split = std.mem.splitSequence(u8, buffer, "\r\n\r\n");

        // TODO : There is something wrong here
        const header = split.next().?;
        var headerToken = std.mem.splitSequence(u8, header, "\r\n");
        var method: HTTPMethod = .GET;
        var path: []const u8 = "";
        var headers = Headers.init(allocator);
        const params = Params.init(allocator);

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

        return Self{
            .method = method,
            .path = path,
            .body = null,
            .headers = headers,
            .params = params,
            .allocator = allocator,
        };
    }

    pub fn parseBody(self: *Self, reader: anytype) !void {
        const length_option = self.headers.get("Content-Length");
        var length: i32 = 0;
        if (length_option != null) length = try std.fmt.parseInt(u8, length_option.?, 10);

        var str = std.ArrayList(u8).init(self.allocator);
        while (length > 0) {
            length -= 1;

            const byte = try reader.readByte();
            try str.append(byte);
        }
        self.body = str;
    }

    pub fn deinit(self: *Self) void {
        self.headers.deinit();
        self.params.deinit();
        if (self.body != null) self.body.?.deinit();
    }
};
