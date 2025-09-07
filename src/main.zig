const std = @import("std");
const lib = @import("raphael_zig_lib");
const flag = @import("flag_zig");

const Http = lib.Http;

const app = @import("./app.zig");
const RaphaelController = app.RaphaelController;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stderr = std.io.getStdErr().writer();

    var args = flag.ArgsParser.init(allocator);
    defer args.deinit();
    const prog = args.program();
    const dir = try args.flag_str("index", null, "Index a directory");
    const search = try args.flag_str("search", null, "Search a term");
    const serve = try args.flag_bool("serve", "Start a local server http://localhost:6969");
    const help = try args.flag_bool("help", "Show this help menu");

    const parse_result = !try args.parse();
    if (parse_result) {
        try usage(stderr, &args, prog.*.?);
        return;
    }

    if (help.*) {
        try usage(stderr, &args, prog.*.?);
        return;
    }

    if (search.* != null) {
        try app.index(allocator, dir.*.?);
    } else if (serve.*) {
        try app.serve(allocator);
    } else if (dir.* != null) {
        try app.index(allocator, dir.*.?);
    }
}
fn usage(stdout: anytype, args: *flag.ArgsParser, program: []const u8) !void {
    try stdout.print("Raphael is a simple search engine designed for Obsidian vault and also can be used to index a normal markdown file\n\n", .{});
    try stdout.print("USAGE: {s} [OPTIONS]\n", .{program});
    try stdout.print("OPTIONS:\n", .{});
    try args.options_print(stdout);
}
