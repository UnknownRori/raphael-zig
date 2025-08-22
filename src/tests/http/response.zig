const std = @import("std");
const testing = @import("std").testing;

const Response = @import("../../http/http.zig").Response;
const HTTPStatus = @import("../../http/http.zig").Status;

test "Serialize json correctly" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    const data = .{ .msg = "Hello, world" };
    const expected_json = try std.json.stringifyAlloc(allocator, data, .{});
    defer allocator.free(expected_json);

    try response.json(.Ok, data);

    try testing.expectEqual(.Ok, response.status);
    try testing.expectEqual(.JSON, response.content_type);
    try testing.expectEqualStrings(expected_json, response.body.?);
}
