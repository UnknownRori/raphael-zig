const std = @import("std");

pub const Lexer = @import("./lexer.zig").Lexer;
pub const TermFreq = @import("./tf.zig").TermFreq;
pub const TermFreqIndex = @import("./tf.zig").TermFreqIndex;

pub const utils = @import("./utils/utils.zig");

pub const Http = @import("./http/http.zig");

const Allocator = std.mem.Allocator;

fn json_config() std.json.StringifyOptions {
    const mode = @import("builtin").mode;
    if (mode == .Debug) {
        return std.json.StringifyOptions{ .whitespace = .indent_1 };
    }

    return std.json.StringifyOptions{ .whitespace = .minified };
}

pub fn cmd_index(allocator: Allocator, directory: []const u8) !void {
    var tfi = TermFreqIndex.init(allocator);
    defer tfi.deinit();

    try tfi.index(directory);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var jw = std.json.writeStream(buffer.writer(), json_config());
    defer jw.deinit();
    try tfi.serializeJson(&jw);

    var index_file = try std.fs.cwd().createFile("index.json", .{});
    defer index_file.close();
    try index_file.writeAll(buffer.items);
}

pub fn load_index(allocator: Allocator) !TermFreqIndex {
    var str = std.ArrayList(u8).init(allocator);
    defer str.deinit();

    var fd = try std.fs.cwd().openFile("index.json", .{});
    defer fd.close();
    var buf_reader = std.io.bufferedReader(fd.reader());
    var in_reader = buf_reader.reader();

    var buf: [4096]u8 = undefined;
    while (try in_reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try str.appendSlice(line);
        try str.append('\n');
    }
    return try TermFreqIndex.fromJson(allocator, str.items);
}

test {
    _ = @import("./tests/all.zig");
}
