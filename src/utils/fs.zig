const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn read_file(allocator: Allocator, dir: std.fs.Dir, filename: []const u8) ![]u8 {
    const stat = try dir.statFile(filename);
    const content = try dir.readFileAlloc(allocator, filename, stat.size);
    return content;
}
