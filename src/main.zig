const std = @import("std");
const lib = @import("raphael_zig_lib");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const file_name = "./data/Procrastination.md";
    const file = try std.fs.cwd().readFileAlloc(allocator, file_name, 4096);
    defer allocator.free(file);

    var lexer = lib.Lexer.init(allocator);

    var tf = try lexer.parse(file);
    defer tf.deinit();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    var jw = std.json.writeStream(buffer.writer(), .{ .whitespace = .minified });
    try jw.beginObject();

    var tf_iter = tf.iterator();
    try jw.objectField(file_name);
    try jw.beginObject();
    while (tf_iter.next()) |e| {
        try stdout.print("{s} -> {d}\n", .{ e.key_ptr.*, e.value_ptr.* });
        try jw.objectField(e.key_ptr.*);
        try jw.write(e.value_ptr.*);
    }
    try jw.endObject();
    try jw.endObject();

    var index_file = try std.fs.cwd().createFile("index.json", .{});
    defer index_file.close();
    try index_file.writeAll(buffer.items);

    // try stdout.print("{s}\n", .{buffer.items});
    // _ = stdout;
    try bw.flush();
}
