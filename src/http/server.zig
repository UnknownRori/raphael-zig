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
        var server = try self.addr.listen(.{ .reuse_address = true });
        std.debug.print("Listening at {any}\n", .{server.listen_address.in});
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

    var buffer = std.Io.Writer.Allocating.init(allocator);
    buffer.deinit();
    var writer = buffer.writer;

    var buf: [1024]u8 = undefined;
    var reader = client.stream.reader(&buf).interface_state;

    while (true) {
        _ = reader.stream(&writer, .unlimited) catch {
            break;
        };
    }

    var request = try Request.parseHeader(allocator, buffer.toArrayList().items);
    defer request.deinit();
    try request.parseBody(&reader);

    std.debug.print("[{s}] {any} - {s}\n", .{ request.method.to_string(), client.address.in, request.path });

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
