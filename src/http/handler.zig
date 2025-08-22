const std = @import("std");

const Request = @import("./request.zig").Request;
const Response = @import("./response.zig").Response;

pub const HandlerFnType = fn (*anyopaque, *Request, *Response) anyerror!void;

pub const Handler = struct {
    ctx: usize,
    handler: usize,

    const Self = @This();

    pub fn init(ctx: *anyopaque, handler: anytype) Self {
        // TODO : Implement type check for this arbitrary pointer
        return Self{
            .ctx = @intFromPtr(ctx),
            .handler = @intFromPtr(&handler),
        };
    }

    pub fn call(self: Self, request: *Request, response: *Response) !void {
        try @call(.auto, @as(*HandlerFnType, @ptrFromInt(self.handler)), .{
            @as(*anyopaque, @ptrFromInt(self.ctx)),
            request,
            response,
        });
    }
};
