const std = @import("std");
const testing = @import("std").testing;

const Request = @import("../../http/http.zig").Request;
const HTTPMethod = @import("../../http/http.zig").Method;

test "Parse basic request data correctly" {
    const allocator = testing.allocator;

    const data = "GET / HTTP/1.1\r\nUser-Agent: Dummy\r\nAccept: text/html\r\n\r\n";

    const request = try Request.parseHeader(allocator, data);
    defer request.deinit();

    try testing.expectEqual(HTTPMethod.GET, request.method);
    try testing.expectEqual(2, request.headers.count());
    try testing.expectEqualStrings("/", request.path);
    try testing.expectEqualStrings("Dummy", request.headers.get("User-Agent").?);
    try testing.expectEqualStrings("text/html", request.headers.get("Accept").?);
    try testing.expectEqual(0, request.body.len);
}

test "Parse basic request data with plain text body correctly" {
    const allocator = testing.allocator;

    const data = "GET / HTTP/1.1\r\nUser-Agent: Dummy\r\nContent-Type: text/plain\r\nContent-Length: 3\r\nAccept: text/html\r\n\r\nHi!";
    var split = std.mem.splitSequence(u8, data, "\r\n\r\n");

    var request = try Request.parseHeader(allocator, split.next().?);
    defer request.deinit();

    var stream = std.io.fixedBufferStream(split.next().?);
    const reader = stream.reader();
    try request.parseBody(reader);

    try testing.expectEqual(HTTPMethod.GET, request.method);
    try testing.expectEqual(4, request.headers.count());
    try testing.expectEqualStrings("/", request.path);
    try testing.expectEqualStrings("Dummy", request.headers.get("User-Agent").?);
    try testing.expectEqualStrings("text/html", request.headers.get("Accept").?);
    try testing.expectEqual(3, request.body.len);
}
