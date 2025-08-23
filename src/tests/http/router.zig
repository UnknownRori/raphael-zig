const std = @import("std");
const testing = @import("std").testing;

const Route = @import("../../http/http.zig").Route;
const Router = @import("../../http/http.zig").Router;
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
        _ = res;
        const self: *Self = @alignCast(@ptrCast(ctx));
        self.hello = req.path;
    }
};

test "Should init route with empty array" {
    const allocator = testing.allocator;
    const router = Router.init(allocator);
    defer router.deinit();

    try testing.expectEqual(0, router.routes.capacity);
}

test "Should add route correctly" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    var my_hello = hello.init();

    try router.add("/", .GET, &my_hello, hello.execute);
    try testing.expectEqual("/", router.routes.getLast().path);
}

test "Resolve route with correct path and method" {
    const allocator = testing.allocator;

    var my_hello = hello.init();

    var router = Router.init(allocator);
    defer router.deinit();
    try router.get("/", &my_hello, hello.execute);
    try router.get("/hi", &my_hello, hello.execute);
    try router.post("/posting-data", &my_hello, hello.execute);

    const data = "GET /hi HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    const handler = (try router.resolve(&request)).?;
    try handler.call(&request, &response);

    try testing.expectEqualStrings(my_hello.hello, "/hi");
}

test "Should not resolve route with wrong path" {
    const allocator = testing.allocator;

    var my_hello = hello.init();

    var router = Router.init(allocator);
    defer router.deinit();
    try router.get("/", &my_hello, hello.execute);
    try router.get("/hi", &my_hello, hello.execute);
    try router.post("/posting-data", &my_hello, hello.execute);

    const data = "GET /wrong HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    const handler = try router.resolve(&request);
    try testing.expect(handler == null);
}

test "Should not resolve route with wrong method" {
    const allocator = testing.allocator;

    var my_hello = hello.init();

    var router = Router.init(allocator);
    defer router.deinit();
    try router.get("/", &my_hello, hello.execute);
    try router.get("/hi", &my_hello, hello.execute);
    try router.post("/posting-data", &my_hello, hello.execute);

    const data = "POST /hi HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";
    var request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    const handler = try router.resolve(&request);
    try testing.expect(handler == null);
}
