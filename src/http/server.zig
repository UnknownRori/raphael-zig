const std = @import("std");
const net = std.net;

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

const Request = @import("./request.zig").Request;
const Response = @import("./response.zig").Response;
const Router = @import("./router.zig").Router;
const HTTPStatus = @import("./utils.zig").HTTPStatus;

pub const Server = struct {
    addr: net.Address,
    allocator: Allocator,
    router: Router,

    const Self = @This();

    pub fn init(allocator: Allocator, host: []const u8, port: u16, router: Router) !Self {
        const addr = try std.net.Ip4Address.parse(host, port);
        const socket = std.net.Address{
            .in = addr,
        };

        return Self{
            .addr = socket,
            .router = router,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Self) void {
        self.router.deinit();
    }

    pub fn listen(self: *Self) !void {
        var server = try self.addr.listen(.{ .reuse_address = true, .reuse_port = true });
        std.debug.print("Listening at {}\n", .{server.listen_address});
        defer server.deinit();

        // TODO : MEM LEAK SOMEWHERE
        while (true) {
            const client = try server.accept();

            // Just yeet the thread and we don't care about it
            // when we care we put it on thread pool to reuse the thread
            const thd = try std.Thread.spawn(.{ .allocator = self.allocator }, handle, .{ self.allocator, self.router, client });
            thd.detach();
        }
    }
};

fn handle(parent_allocator: Allocator, router: Router, client: net.Server.Connection) !void {
    defer client.stream.close();

    var arena = std.heap.ArenaAllocator.init(parent_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var buffer = String.init(allocator);
    defer buffer.deinit();
    const writer = buffer.writer();

    var buffered_reader = std.io.bufferedReader(client.stream.reader());
    var reader = buffered_reader.reader();

    var buf: [1024]u8 = undefined;
    while (true) {
        const line = reader.readUntilDelimiter(&buf, '\n') catch {
            break;
        };
        const trimmed = std.mem.trimRight(u8, line, "\r");

        if (trimmed.len == 0) break;

        _ = try writer.write(trimmed);
        _ = try writer.write("\r\n");
    }

    var request = try Request.parseHeader(allocator, buffer.items);
    defer request.deinit();
    try request.parseBody(reader);

    std.debug.print("[{s}] {} - {s}\n", .{ request.method.to_string(), client.address, request.path });

    var response = Response.init(allocator);
    defer response.deinit();

    const handler = try router.resolve(&request);
    if (handler == null) {
        try response.json(.NotFound, .{
            .status = "error",
            .message = "Not found",
        });
    } else {
        try handler.?.call(&request, &response);
    }

    try response.send(client.stream);
}
