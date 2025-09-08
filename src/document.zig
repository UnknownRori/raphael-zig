const std = @import("std");
const tf = @import("tf.zig");

const Lexer = @import("lexer.zig").Lexer;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Metadata = @import("metadata.zig").MetaData;
const YAMLParser = @import("./parser/yaml.zig").Parser;
const read_file = @import("./utils/utils.zig").fs.read_file;

pub const Document = struct {
    metadata: Metadata,
    tf: tf.TermFreq,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, metadata: Metadata) !Self {
        return Self{
            .metadata = metadata,
            .tf = try tf.TermFreq.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn parse(allocator: Allocator, contents: []const u8) !Self {
        // TODO : Refactor this stuff
        var metadata = Metadata.init(allocator);
        if (std.mem.startsWith(u8, contents, "---")) {
            var skipHeader = std.mem.splitSequence(u8, contents, "---");
            _ = skipHeader.next().?;
            const header = skipHeader.next().?;
            var parser = try YAMLParser.init(allocator, header);
            const meta = try parser.parse(allocator);
            defer meta.deinit();
            for (meta.items) |item| {
                switch (item) {
                    .Scalar => |n| {
                        if (std.mem.eql(u8, n.key.items, "description")) {
                            try metadata.description.appendSlice(n.value.items);
                        }
                    },
                    .Sequence => |n| {
                        if (std.mem.eql(u8, n.key.items, "tags")) {
                            for (n.value.items) |tag| {
                                var tag_temp = try std.ArrayList(u8).initCapacity(allocator, tag.items.len);
                                try tag_temp.appendSlice(tag.items);
                                try metadata.tags.append(tag_temp);
                            }
                        }
                    },
                    else => {},
                }
            }
        }

        if (metadata.description.items.len <= 0) {
            try metadata.description.appendSlice("No description provided");
        }
        const tf_map = try tf.TermFreq.parse(allocator, contents);

        return Self{
            .metadata = metadata,
            .tf = tf_map,
            .allocator = allocator,
        };
    }

    pub fn deserializeJson(allocator: Allocator, object: std.json.ObjectMap) !Self {
        const metadata = try Metadata.deserializeJson(allocator, object.get("metadata").?.object);
        var self = try Self.init(allocator, metadata);

        const tf_json = object.get("tf").?.object;
        for (tf_json.keys(), tf_json.values()) |key_tf, value_tf| {
            const term = try allocator.dupe(u8, key_tf);

            try self.tf.map.put(term, @intCast(value_tf.integer));
        }

        return self;
    }

    pub fn serializeJson(self: Self, jw: anytype) !void {
        try jw.beginObject();
        try jw.objectField("metadata");
        try self.metadata.serializeJson(jw);

        try jw.objectField("tf");
        try self.tf.serializeJson(jw);
        try jw.endObject();
    }

    pub fn contains(self: Self, token: []const u8) bool {
        return self.tf.contains(token);
    }

    pub fn deinit(self: *Self) void {
        self.metadata.deinit();
        self.tf.deinit();
    }
};

pub const TermFreqDocuments = struct {
    map: std.StringHashMap(Document),
    arena: ArenaAllocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .map = std.StringHashMap(Document).init(allocator),
            .arena = ArenaAllocator.init(allocator),
        };
    }

    pub fn fromJson(parent_allocator: Allocator, contents: []const u8) !Self {
        var tfi = TermFreqDocuments.init(parent_allocator);
        const allocator = tfi.arena.allocator();

        const a = try std.json.parseFromSlice(std.json.Value, parent_allocator, contents, .{ .allocate = .alloc_always });
        defer a.deinit();

        for (a.value.object.keys(), a.value.object.values()) |key, value| {
            const tf_map = try Document.deserializeJson(allocator, value.object);
            const name = try allocator.dupe(u8, key);
            try tfi.map.put(name, tf_map);
        }
        return tfi;
    }

    pub fn index_recursive(self: *Self, dir: std.fs.Dir) !void {
        const allocator = self.arena.allocator();

        var it = dir.iterate();
        while (try it.next()) |val| {
            // Skip non md file
            // TODO : Make it work with .txt too, and check if it work with symlink file
            if (!std.mem.containsAtLeast(u8, val.name, 1, ".") and (val.kind == .directory or val.kind == .sym_link)) {
                var new_dir = try dir.openDir(val.name, .{ .iterate = true });
                defer new_dir.close();
                try self.index_recursive(new_dir);
            }

            if (!std.mem.containsAtLeast(u8, val.name, 1, ".md") or
                std.mem.containsAtLeast(u8, val.name, 1, ".excalidraw") or
                std.mem.containsAtLeast(u8, val.name, 1, ".kanban") or
                val.kind != .file)
            {
                continue;
            }

            std.debug.print("Reading: {s}\n", .{val.name});
            const file = try read_file(allocator, dir, val.name);

            const tf_map = Document.parse(allocator, file) catch |err| {
                if (err == std.mem.Allocator.Error.OutOfMemory) {
                    @panic("[-] Buy more RAM yo, lol\n");
                }
                std.debug.print("[-] Caught and error", .{});
                continue;
            };
            const name = try dir.realpathAlloc(allocator, val.name);
            try self.map.put(name, tf_map);
        }
    }
    pub fn index(self: *Self, directory: []const u8) !void {
        var dir = try std.fs.cwd().openDir(directory, .{ .iterate = true });
        defer dir.close();

        std.debug.print("Parsing directory: {s} \n", .{directory});
        try self.index_recursive(dir);

        std.debug.print("\n--------------\n", .{});
        std.debug.print("Indexed: {d} files\n", .{self.map.count()});
    }

    pub fn search(self: *Self, allocator: Allocator, term: []const u8) !std.ArrayList(SearchResult) {
        var result = std.ArrayList(SearchResult).init(allocator);

        var tfi_iter = self.map.iterator();
        const term_uppercase = try std.ascii.allocUpperString(allocator, term);
        defer allocator.free(term_uppercase);
        while (tfi_iter.next()) |e| {
            var lexer = Lexer.init(term_uppercase);
            var rank: f32 = 0;

            while (lexer.next()) |token| {
                rank += calc_tf(e.value_ptr.tf, token) * calc_idf(self.map, token);
            }

            // We don't give a frick with infinite rank like ur mom
            if (std.math.isInf(rank) or std.math.isNan(rank) or rank <= 0) continue;

            try result.append(SearchResult.init(e.key_ptr.*, e.value_ptr.metadata, rank));
        }

        std.mem.sort(SearchResult, result.items, {}, SearchResult.compareAsc);

        return result;
    }

    pub fn serializeJson(self: Self, jw: anytype) !void {
        var tf_iter = self.map.iterator();
        try jw.beginObject();

        while (tf_iter.next()) |e| {
            try jw.objectField(e.key_ptr.*);
            try e.value_ptr.*.serializeJson(jw);
        }

        try jw.endObject();
    }

    pub fn deinit(self: Self) void {
        self.arena.deinit();
    }
};

pub const SearchResult = struct {
    filepath: []const u8,
    metadata: Metadata,
    weight: f32,

    const Self = @This();

    pub fn init(filepath: []const u8, metadata: Metadata, weight: f32) Self {
        return Self{
            .filepath = filepath,
            .metadata = metadata,
            .weight = weight,
        };
    }

    pub fn compareAsc(context: void, lhs: Self, rhs: Self) bool {
        _ = context;
        return lhs.weight > rhs.weight;
    }

    pub fn print(self: Self) void {
        std.debug.print("{s} -> %{d:.2} ({d})\n", .{ self.filepath, self.weight * 1000, self.weight });
    }
};

fn calc_tf(tf_table: tf.TermFreq, term: []const u8) f32 {
    const a: f32 = @floatFromInt(tf_table.getOr(term, 0));
    const b: f32 = @floatFromInt(tf_table.sum());
    return a / b;
}

fn calc_idf(idf_table: std.StringHashMap(Document), term: []const u8) f32 {
    const a: f32 = @floatFromInt(idf_table.count());
    var count: u32 = 0;

    var tfi_iter = idf_table.iterator();
    while (tfi_iter.next()) |e| {
        if (e.value_ptr.contains(term)) {
            count += 1;
        }
    }

    const count_float: f32 = @floatFromInt(count);
    return std.math.log10((a / count_float));
}
