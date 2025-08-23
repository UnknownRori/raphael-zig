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
        const tfi = try lib.load_index(allocator);

        var router = lib.Http.Router.init(allocator);

        var raphael_controller = RaphaelController.init(tfi);
        defer raphael_controller.deinit();

        try router.get("/", &raphael_controller, RaphaelController.home);
        try router.post("/query", &raphael_controller, RaphaelController.query);
        try router.get("/*", &raphael_controller, RaphaelController.assets);

        var server = try lib.Http.Server.init(allocator, "127.0.0.1", 6969, router);
        try server.listen();
    }
}

const Http = lib.Http;
const Request = lib.Http.Request;
const Response = lib.Http.Response;
const read_file = lib.utils.fs.read_file;

const RaphaelController = struct {
    tfi: lib.TermFreqIndex,
    const Self = @This();

    pub fn init(tfi: lib.TermFreqIndex) Self {
        return Self{
            .tfi = tfi,
        };
    }

    pub fn deinit(self: Self) void {
        self.tfi.deinit();
    }

    pub fn assets(ctx: *anyopaque, req: *Request, res: *Response) !void {
        _ = ctx;
        // TODO : Create abstraction for this thing
        const dir = try std.fs.cwd().openDir("./src-web/", .{ .iterate = true });
        const contents = read_file(res.arena.allocator(), dir, req.path[1..]) catch |err| {
            std.debug.print("[-] {any}\n", .{err});
            return try res.json(.NotFound, .{ .message = "File not found" });
        };
        const extension = std.fs.path.extension(req.path);
        const mime = Http.utils.match_mime_type(extension);

        try res.response(.Ok, mime.content_type, contents);
    }

    pub fn home(ctx: *anyopaque, req: *Request, res: *Response) !void {
        _ = req;
        _ = ctx;
        try res.file(.Ok, .HTML, "./src-web/index.html");
    }

    pub fn query(ctx: *anyopaque, req: *Request, res: *Response) !void {
        const self: *Self = @alignCast(@ptrCast(ctx));
        const allocator = res.arena.allocator(); // Borrowing shit

        var data = std.json.parseFromSlice(std.json.Value, allocator, req.body, .{}) catch |err| {
            std.debug.print("{any}\n", .{err});
            return try res.json(.InternalServerError, .{
                .status = "error",
                .message = "Parsing json failed",
            });
        };
        defer data.deinit();

        const query_input = data.value.object.get("query").?.string;
        const result = try self.tfi.search(query_input);
        defer result.deinit();

        var result_item = std.ArrayList(QueryResult).init(allocator);

        var i: usize = 0;
        for (result.items) |item| {
            if (i > 4) break;
            i += 1;

            const data_query: QueryResult = .{
                .name = std.fs.path.basename(item.filepath),
                .path = item.filepath,
                .weight = item.weight,
            };

            try result_item.append(data_query);
        }

        try res.json(.Ok, .{ .result = result_item.items });
    }
};

const QueryResult = struct {
    name: []const u8,
    path: []const u8,
    weight: f32,
};
