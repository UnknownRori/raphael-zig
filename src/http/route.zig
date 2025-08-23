const std = @import("std");

const Request = @import("./request.zig").Request;
const Response = @import("./request.zig").Response;
const Handler = @import("./handler.zig").Handler;
const HTTPMethod = @import("./utils.zig").HTTPMethod;

pub const Route = struct {
    path: []const u8,
    method: HTTPMethod,

    handler: Handler,

    const Self = @This();

    pub fn init(path: []const u8, method: HTTPMethod, ctx: anytype, handler: anytype) Self {
        const route_handler = Handler.init(ctx, handler);

        return Self{
            .path = path,
            .method = method,
            .handler = route_handler,
        };
    }

    pub fn resolve(self: Self, request: *Request) !bool {
        if (request.method != self.method) return false;

        var url = std.mem.splitSequence(u8, request.path, "/");
        var route_url = std.mem.splitSequence(u8, self.path, "/");

        while (url.next()) |request_url| {
            const route_option = route_url.next();
            if (route_option == null) return false;
            const route = route_option.?;

            if (std.mem.eql(u8, "*", route)) return true;
            if (route.len > 1) {
                if (route[0] == '{' and route[route.len - 1] == '}') {
                    // TODO : There is something wrong with this causing segfault
                    const name = route[1 .. route.len - 2];
                    _ = try request.params.getOrPutValue(name, request_url);
                }
            }
            if (!std.mem.eql(u8, route, request_url)) return false;
        }
        return true;
    }
};
