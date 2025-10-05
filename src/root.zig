const std = @import("std");

pub const Lexer = @import("./lexer.zig").Lexer;
pub const TermFreqDocument = @import("./document.zig").TermFreqDocuments;
pub const Metadata = @import("./metadata.zig").MetaData;

pub const utils = @import("./utils/utils.zig");

pub const Http = @import("./http/http.zig");

const Allocator = std.mem.Allocator;

fn json_config() std.json.Stringify.Options {
    const mode = @import("builtin").mode;
    if (mode == .Debug) {
        return std.json.Stringify.Options{ .whitespace = .indent_1 };
    }

    return std.json.Stringify.Options{ .whitespace = .minified };
}

pub fn cmd_index(allocator: Allocator, directory: []const u8) !void {
    var tfi = TermFreqDocument.init(allocator);
    defer tfi.deinit();

    try tfi.index(directory);

    var buffer_allocating = try std.Io.Writer.Allocating.initCapacity(allocator, 4096 * 4096);
    defer buffer_allocating.deinit();
    var writer = buffer_allocating.writer;
    var jw = std.json.Stringify{ .writer = &writer, .options = json_config() };
    try tfi.serializeJson(&jw);

    const str = writer.buffered();
    try writer.flush();

    var index_file = try std.fs.cwd().createFile("index.json", .{});
    defer index_file.close();
    try index_file.writeAll(str);
}

pub fn load_index(allocator: Allocator) !TermFreqDocument {
    // var allocating = try std.Io.Writer.Allocating.initCapacity(allocator, 4096);
    // defer allocating.deinit();
    // var writer = allocating.writer;

    var str = try std.ArrayList(u8).initCapacity(allocator, 1);

    var fd = try std.fs.cwd().openFile("./index.json", .{ .mode = .read_only });
    defer fd.close();
    const stat = try fd.stat();
    const buf = try allocator.alloc(u8, stat.size);
    defer allocator.free(buf);
    var reader = fd.reader(buf);

    while (reader.interface.takeDelimiterExclusive('\n')) |line| {
        try str.appendSlice(allocator, line);
        // allocating.clearRetainingCapacity();
    } else |err| switch (err) {
        error.EndOfStream => {},
        error.ReadFailed, error.StreamTooLong => return err,
    }
    // std.debug.print("{s}\n", .{str.items});
    return try TermFreqDocument.fromJson(allocator, str.items);
}

test {
    _ = @import("./tests/all.zig");
}
