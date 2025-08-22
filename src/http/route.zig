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

    pub fn resolve(self: Self, request: *Request) bool {
        // TODO: Resolve params dynamically
        if (std.mem.eql(u8, self.path, request.path) and self.method == request.method) return true;
        return false;
    }
};
