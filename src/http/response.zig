const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const String = std.ArrayList(u8);

const HTTPStatus = @import("./utils.zig").HTTPStatus;
const ContentType = @import("./utils.zig").ContentType;
const Headers = @import("./utils.zig").Headers;

pub const Response = struct {
    status: HTTPStatus,
    content_type: ContentType,
    body: ?[]const u8,
    headers: Headers,
    arena: ArenaAllocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .status = HTTPStatus.NotFound,
            .content_type = .BLOB,
            .body = null,
            .headers = Headers.init(allocator),
            .arena = ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: Self) void {
        self.arena.deinit();
    }

    pub fn response(self: *Self, code: HTTPStatus, content_type: ContentType, content: anytype) !void {
        self.status = code;
        self.content_type = content_type;
        self.body = content;
    }

    pub fn json(self: *Self, code: HTTPStatus, content: anytype) !void {
        const data = try std.json.stringifyAlloc(self.arena.allocator(), content, .{});
        try self.response(code, .JSON, data);
    }

    pub fn send(self: *Self, stream: std.net.Stream) !void {
        var strResponse = try std.ArrayList(u8).initCapacity(self.arena.allocator(), 1024);
        defer strResponse.deinit();

        const httpCode = try std.fmt.allocPrint(self.arena.allocator(), "HTTP/1.1 {} {s}\r\n", .{
            @intFromEnum(self.status),
            self.status.to_string(),
        });
        defer self.arena.allocator().free(httpCode);
        try strResponse.appendSlice(httpCode);

        if (self.body != null) {
            const content_type = try std.fmt.allocPrint(self.arena.allocator(), "Content-Type: {s}\r\n", .{self.content_type.to_string()});
            try strResponse.appendSlice(content_type);
            defer self.arena.allocator().free(content_type);

            const content_length = try std.fmt.allocPrint(self.arena.allocator(), "Content-Length: {}\r\n\r\n", .{self.body.?.len});
            try strResponse.appendSlice(content_length);
            defer self.arena.allocator().free(content_length);

            try strResponse.appendSlice(self.body.?);
        }

        _ = try stream.write(strResponse.items);
    }
};
