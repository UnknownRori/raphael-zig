const std = @import("std");
const testing = @import("std").testing;

const Route = @import("../../http/http.zig").Route;
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

test "Resolve route with correct path and method" {
    const allocator = testing.allocator;

    var my_hello = hello.init();
    const route = Route.init("/", .GET, &my_hello, hello.execute);

    const data = "GET / HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    try testing.expect(try route.resolve(&request));
    try testing.expect(request.headers.contains("Accept"));
    try testing.expect(request.headers.contains("User-Agent"));
}

test "Should not resolve route with wrong path" {
    const allocator = testing.allocator;

    var my_hello = hello.init();
    const route = Route.init("/", .GET, &my_hello, hello.execute);

    const data = "GET /hi HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    try testing.expect(!(try route.resolve(&request)));
}

test "Should not resolve route with wrong method" {
    const allocator = testing.allocator;

    var my_hello = hello.init();
    const route = Route.init("/", .GET, &my_hello, hello.execute);

    const data = "POST / HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    try testing.expect(!(try route.resolve(&request)));
}

test "Should resolve route that *" {
    const allocator = testing.allocator;

    var my_hello = hello.init();
    const route = Route.init("/statics/*", .GET, &my_hello, hello.execute);

    const data = "GET /statics/nyan HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    try testing.expect(try route.resolve(&request));
}

test "Should resolve route that dynamic {nyan}" {
    const allocator = testing.allocator;

    var my_hello = hello.init();
    const route = Route.init("/statics/{nyan}", .GET, &my_hello, hello.execute);

    const data = "GET /statics/cat HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    try testing.expect(try route.resolve(&request));
    try testing.expect(request.params.contains("nyan"));
    try testing.expectEqualStrings("cat", request.params.get("nyan").?);
}
