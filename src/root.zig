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

    var buffer_allocating = std.Io.Writer.Allocating.init(allocator);
    try buffer_allocating.ensureTotalCapacity(1024 * 1024);
    var writer = buffer_allocating.writer;
    var jw = std.json.Stringify{ .writer = &writer, .options = json_config() };
    try tfi.serializeJson(&jw);
    try writer.flush();

    var index_file = try std.fs.cwd().createFile("index.json", .{});
    defer index_file.close();
    try index_file.writeAll(writer.buffer);
}

pub fn load_index(allocator: Allocator) !TermFreqDocument {
    var str = try std.ArrayList(u8).initCapacity(allocator, 4096);
    defer str.deinit(allocator);

    var fd = try std.fs.cwd().openFile("index.json", .{});
    defer fd.close();
    var buffer: [4096]u8 = undefined;
    var buf_reader = fd.reader(&buffer);

    var buf: [4096]u8 = undefined;
    while (buf_reader.atEnd()) {
        const size = buf_reader.read(&buf) catch {
            break;
        };
        try str.appendSlice(allocator, buf[0..size]);
    }
    return try TermFreqDocument.fromJson(allocator, str.items);
}

test {
    _ = @import("./tests/all.zig");
}
