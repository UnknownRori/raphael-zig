const std = @import("std");
const net = std.net;

const Allocator = std.mem.Allocator;

pub const Server = struct {
    addr: net.Address,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, host: []const u8, port: u16) !Self {
        const addr = try std.net.Ip4Address.parse(host, port);
        const socket = std.net.Address{
            .in = addr,
        };

        return Self{
            .addr = socket,
            .allocator = allocator,
        };
    }

    pub fn listen(self: *Self) !void {
        var server = try self.addr.listen(.{ .reuse_address = true, .reuse_port = true });
        std.debug.print("Listening at {}\n", .{server.listen_address});
        defer server.deinit();

        while (true) {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            const allocator = arena.allocator();
            defer arena.deinit();

            const client = try server.accept();
            defer client.stream.close();

            const buffer = try allocator.alloc(u8, 2024);
            defer allocator.free(buffer);

            _ = try client.stream.read(buffer);
            _ = try client.stream.writeAll("HTTP/1.1 200 OK\r\n");
            std.debug.print("{s}\n", .{buffer});
        }
    }
};
