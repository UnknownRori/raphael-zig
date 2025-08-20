const std = @import("std");
const lib = @import("raphael_zig_lib");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    // defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var tfi = lib.TermFreqIndex.init(allocator);
    defer tfi.deinit();

    try tfi.index("./data/");

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var jw = std.json.writeStream(buffer.writer(), .{ .whitespace = .indent_1 });
    defer jw.deinit();
    try tfi.serializeJson(&jw);

    var index_file = try std.fs.cwd().createFile("index.json", .{});
    defer index_file.close();
    try index_file.writeAll(buffer.items);

    _ = stdout;
    try bw.flush();

    // TODO: FIX MEMORY LEAK
    // const leaks = gpa.detectLeaks();
    // std.debug.print("has leaks : {}", .{leaks});
}
