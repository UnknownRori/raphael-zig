const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const Route = @import("./route.zig").Route;
const Request = @import("./request.zig").Request;
const Handler = @import("./handler.zig").Handler;
const Method = @import("./utils.zig").HTTPMethod;

pub const Router = struct {
    routes: std.ArrayList(Route),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .routes = std.ArrayList(Route).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Self) void {
        self.routes.deinit();
    }

    pub fn add(self: *Self, path: []const u8, method: Method, ctx: *anyopaque, handler: anytype) !void {
        try self.routes.append(Route.init(path, method, ctx, handler));
    }

    pub fn get(self: *Self, path: []const u8, ctx: *anyopaque, handler: anytype) !void {
        try self.add(path, .GET, ctx, handler);
    }

    pub fn post(self: *Self, path: []const u8, ctx: *anyopaque, handler: anytype) !void {
        try self.add(path, .POST, ctx, handler);
    }

    pub fn patch(self: *Self, path: []const u8, ctx: *anyopaque, handler: anytype) !void {
        try self.add(path, .PATCH, ctx, handler);
    }

    pub fn delete(self: *Self, path: []const u8, ctx: *anyopaque, handler: anytype) !void {
        try self.add(path, .DELETE, ctx, handler);
    }

    pub fn resolve(self: Self, request: *Request) ?Handler {
        for (self.routes.items) |route| {
            const valid = route.resolve(request);
            if (valid) return route.handler;
        }

        return null;
    }
};
