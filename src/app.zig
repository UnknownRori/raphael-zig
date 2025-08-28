const std = @import("std");
const lib = @import("raphael_zig_lib");

const Http = lib.Http;
const Request = lib.Http.Request;
const Response = lib.Http.Response;
const read_file = lib.utils.fs.read_file;
const Metadata = lib.Metadata;

pub fn usage(writer: anytype, args: [][:0]u8) !void {
    try writer.print("Usage {s} <command>\n", .{args[0]});
    try writer.print("Command: \n", .{});
    try writer.print("\t index  <directory>\n", .{});
    try writer.print("\t search <term>\n", .{});
    try writer.print("\t serve\n", .{});
}

pub fn search(allocator: std.mem.Allocator, writer: anytype, args: [][:0]u8) !void {
    if (args.len <= 3) {
        const term = args[2];

        var tfi = try lib.load_index(allocator);
        defer tfi.deinit();

        const result = try tfi.search(allocator, term);
        defer result.deinit();
        for (result.items) |item| {
            item.print();
        }
        return;
    }

    try writer.print("Usage {s} search <term>\n", .{args[0]});
}

pub fn index(allocator: std.mem.Allocator, writer: anytype, args: [][:0]u8) !void {
    if (args.len <= 3) {
        const directory = args[2];
        try lib.cmd_index(allocator, directory);
        return;
    }

    try writer.print("Usage {s} index <directory>\n", .{args[0]});
}

pub fn serve(allocator: std.mem.Allocator) !void {
    const tfi = try lib.load_index(allocator);

    var router = lib.Http.Router.init(allocator);

    var raphael_controller = RaphaelController.init(tfi);
    defer raphael_controller.deinit();

    router.not_found = Http.Handler.init(&raphael_controller, RaphaelController.not_found);
    try router.get("/", &raphael_controller, RaphaelController.home);
    try router.post("/query", &raphael_controller, RaphaelController.query);
    try router.post("/show", &raphael_controller, RaphaelController.show);

    // Statics Assets
    try router.get("/statics/*", &raphael_controller, RaphaelController.assets);

    var server = try lib.Http.Server.init(allocator, "127.0.0.1", 6969, router);
    try server.listen();
}

pub const RaphaelController = struct {
    tfi: lib.TermFreqDocument,
    const Self = @This();

    pub fn init(tfi: lib.TermFreqDocument) Self {
        return Self{
            .tfi = tfi,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tfi.deinit();
    }

    pub fn not_found(ctx: *anyopaque, req: *Request, res: *Response) !void {
        _ = req;
        _ = ctx;
        try res.file(.Ok, .HTML, "./src-web/404.html");
    }

    pub fn assets(ctx: *anyopaque, req: *Request, res: *Response) !void {
        _ = ctx;
        // TODO : Create abstraction for this thing
        const dir = try std.fs.cwd().openDir("./src-web", .{ .iterate = true });
        const path = try std.mem.replaceOwned(u8, res.arena.allocator(), req.path[1..], "../", "");
        const contents = read_file(res.arena.allocator(), dir, path) catch |err| {
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

    pub fn show(ctx: *anyopaque, req: *Request, res: *Response) !void {
        const self: *Self = @alignCast(@ptrCast(ctx));
        const allocator = res.arena.allocator(); // Borrowing shit

        var data = std.json.parseFromSlice(std.json.Value, allocator, req.body.?.items, .{}) catch |err| {
            std.debug.print("{any}\n", .{err});
            return try res.json(.InternalServerError, .{
                .status = "error",
                .message = "Parsing json failed",
            });
        };
        defer data.deinit();

        const query_input = data.value.object.get("file").?.string;
        const result = try self.tfi.search(allocator, query_input);
        defer result.deinit();

        const dir = try std.fs.cwd().openDir(std.fs.path.dirname(query_input).?, .{ .iterate = true });
        const contents = read_file(res.arena.allocator(), dir, std.fs.path.basename(query_input)) catch |err| {
            std.debug.print("[-] {any}\n", .{err});
            return try res.json(.NotFound, .{ .message = "File not found" });
        };

        try res.json(.Ok, .{ .status = "success", .data = contents });
    }

    pub fn query(ctx: *anyopaque, req: *Request, res: *Response) !void {
        const self: *Self = @alignCast(@ptrCast(ctx));
        const allocator = res.arena.allocator(); // Borrowing shit

        var data = std.json.parseFromSlice(std.json.Value, allocator, req.body.?.items, .{}) catch |err| {
            std.debug.print("{any}\n", .{err});
            return try res.json(.InternalServerError, .{
                .status = "error",
                .message = "Parsing json failed",
            });
        };
        defer data.deinit();

        const query_input = data.value.object.get("query").?.string;
        const result = try self.tfi.search(allocator, query_input);
        defer result.deinit();

        var result_item = std.ArrayList(QueryResult).init(allocator);

        var i: usize = 0;
        for (result.items) |item| {
            if (i > 4) break;
            i += 1;

            var tags = std.ArrayList([]u8).init(allocator);
            for (item.metadata.tags.items) |tag| {
                try tags.append(tag.items);
            }

            const data_query: QueryResult = .{
                .name = std.fs.path.basename(item.filepath),
                .metadata = .{
                    .description = item.metadata.description.items,
                    .tags = tags.items,
                },
                .path = item.filepath,
                .weight = item.weight,
            };

            try result_item.append(data_query);
        }

        try res.json(.Ok, .{ .status = "success", .result = result_item.items });
    }
};

const QueryResult = struct {
    name: []const u8,
    path: []const u8,
    metadata: struct {
        description: []const u8,
        tags: [][]u8,
    },
    weight: f32,
};
