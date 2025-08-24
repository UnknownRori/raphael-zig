const std = @import("std");
const lib = @import("raphael_zig_lib");

const Http = lib.Http;

const app = @import("./app.zig");
const RaphaelController = app.RaphaelController;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        try app.usage(stdout, args);
        try bw.flush();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, "index", command)) {
        try app.index(allocator, stdout, args);
    }

    if (std.mem.eql(u8, "search", command)) {
        try app.search(allocator, stdout, args);
    }

    if (std.mem.eql(u8, "serve", command)) {
        try app.serve(allocator);
    }
}
