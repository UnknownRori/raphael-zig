const std = @import("std");
const lib = @import("raphael_zig_lib");

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
        try stdout.print("Usage {s} <command>\n", .{args[0]});
        try stdout.print("Command: \n", .{});
        try stdout.print("\t index  <directory>\n", .{});
        try stdout.print("\t search <term>\n", .{});
        try stdout.print("\t serve\n", .{});
        try bw.flush();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, "index", command)) {
        if (args.len <= 3) {
            const directory = args[2];
            try lib.cmd_index(allocator, directory);
            return;
        }

        try stdout.print("Usage {s} index <directory>\n", .{args[0]});
    }

    if (std.mem.eql(u8, "search", command)) {
        if (args.len <= 3) {
            const search = args[2];

            var tfi = try lib.load_index(allocator);
            defer tfi.deinit();

            const result = try tfi.search(search);
            for (result.items) |item| {
                item.print();
            }
            return;
        }

        try stdout.print("Usage {s} search <term>\n", .{args[0]});
    }

    if (std.mem.eql(u8, "serve", command)) {
        var tfi = try lib.load_index(allocator);
        defer tfi.deinit();

        var router = lib.Http.Router.init(allocator);

        var raphael_controller = RaphaelController.init();

        try router.get("/", &raphael_controller, RaphaelController.home);

        var server = try lib.Http.Server.init(allocator, "127.0.0.1", 6969, router);
        try server.listen();
    }
}

const Request = lib.Http.Request;
const Response = lib.Http.Response;

const RaphaelController = struct {
    const Self = @This();

    pub fn init() Self {
        return Self{};
    }

    pub fn home(ctx: *anyopaque, req: *Request, res: *Response) !void {
        _ = req;
        _ = ctx;
        try res.file(.Ok, .HTML, "./src-web/index.html");
    }
};
