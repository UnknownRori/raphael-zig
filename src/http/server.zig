const std = @import("std");
const net = std.net;

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

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

            var buffer = String.init(allocator);
            defer buffer.deinit();
            const writer = buffer.writer();

            var buffered_reader = std.io.bufferedReader(client.stream.reader());
            var reader = buffered_reader.reader();

            // TODO : Parse response body
            var buf: [1024]u8 = undefined;
            while (true) {
                const line = try reader.readUntilDelimiter(&buf, '\n');
                const trimmed = std.mem.trimRight(u8, line, "\r");

                if (trimmed.len == 0) break;

                _ = try writer.write(trimmed);
                std.debug.print("{s}\n", .{trimmed});
            }
            _ = try client.stream.writeAll("HTTP/1.1 200 OK\r\n");
            std.debug.print("{s}\n", .{buf});
        }
    }
};
