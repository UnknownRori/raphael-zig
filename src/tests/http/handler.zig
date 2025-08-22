const std = @import("std");
const testing = @import("std").testing;

const Request = @import("../../http/http.zig").Request;
const Response = @import("../../http/http.zig").Response;
const Handler = @import("../../http/http.zig").Handler;

const hello = struct {
    hello: []const u8,

    const Self = @This();
    pub fn init() Self {
        return Self{
            .hello = "Hello",
        };
    }

    pub fn execute(ctx: *anyopaque, req: *Request, res: *Response) !void {
        _ = req;
        _ = res;
        const self: *Self = @alignCast(@ptrCast(ctx));

        try testing.expectEqualStrings(self.hello, "Hello");
    }
};

test "Handler should call correctly" {
    const allocator = testing.allocator;
    var request = try Request.parseHeader(allocator, "GET / HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    var my_hello = hello.init();

    var handler = Handler.init(&my_hello, hello.execute);
    try handler.call(&request, &response);
}
