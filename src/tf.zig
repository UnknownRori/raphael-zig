const std = @import("std");
const testing = std.testing;

const Lexer = @import("./lexer.zig").Lexer;
const end_line = @import("./utils.zig").end_line;

const Allocator = std.mem.Allocator;

pub const TermFreq = struct {
    map: std.StringHashMap(u32),
    allocator: Allocator,
    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .map = std.StringHashMap(u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn from(map: std.StringHashMap(u32)) Self {
        return Self{
            .map = map,
            .allocator = map.allocator,
        };
    }

    pub fn print(self: Self) void {
        var it = self.map.iterator();
        while (it.next()) |e| {
            std.debug.print("{s} -> {d}\n", .{ e.key_ptr.*, e.value_ptr.* });
        }
    }

    pub fn serializeJson(self: Self, jw: anytype) !void {
        var tf_iter = self.map.iterator();
        try jw.beginObject();
        while (tf_iter.next()) |e| {
            try jw.objectField(e.key_ptr.*);
            try jw.write(e.value_ptr.*);
        }
        try jw.endObject();
    }

    pub fn sum(self: Self) u32 {
        var weight: u32 = 0;
        var tf_iter = self.map.iterator();
        while (tf_iter.next()) |e| {
            weight += e.value_ptr.*;
        }
        return weight;
    }

    pub fn search(self: Self, term: []const u8) u32 {
        var weight: u32 = 0;
        var tokens = std.mem.tokenizeSequence(u8, term, " ");
        while (tokens.next()) |token| {
            const value = self.map.get(token);
            if (value != null) {
                weight += value.?;
            }
        }
        return weight;
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }
};

pub const TermFreqIndex = struct {
    map: std.StringHashMap(TermFreq),
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .map = std.StringHashMap(TermFreq).init(allocator),
            .arena = std.heap.ArenaAllocator.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn from(map: std.StringHashMap(TermFreq)) Self {
        return Self{
            .map = map,
            .arena = std.heap.ArenaAllocator.init(map.allocator),
            .allocator = map.allocator,
        };
    }

    /// This function create new [`TermFreqIndex`] based on contents
    pub fn fromJson(parent_allocator: std.mem.Allocator, contents: []const u8) !Self {
        var tfi = TermFreqIndex.init(parent_allocator);
        const allocator = tfi.arena.allocator();

        const a = try std.json.parseFromSlice(std.json.Value, parent_allocator, contents, .{ .allocate = .alloc_always });
        defer a.deinit();

        for (a.value.object.keys(), a.value.object.values()) |key, value| {
            var tf = TermFreq.init(allocator);
            for (value.object.keys(), value.object.values()) |key_tf, value_tf| {
                const term = try allocator.dupe(u8, key_tf);

                try tf.map.put(term, @intCast(value_tf.integer));
            }

            const name = try allocator.dupe(u8, key);
            try tfi.map.put(name, tf);
        }
        return tfi;
    }

    /// This function will index [`Dir`]
    pub fn index_recursive(self: *Self, dir: std.fs.Dir) !void {
        const allocator = self.arena.allocator();
        const lexer = Lexer.init(allocator);

        var it = dir.iterate();
        while (try it.next()) |val| {
            // Skip non md file
            // TODO : Make it work with .txt too and recursively
            if (val.kind == .directory) {
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
            const stat = try dir.statFile(val.name);
            const file = try dir.readFileAlloc(allocator, val.name, stat.size);

            const tf_map = lexer.parse(file) catch |err| {
                if (err == std.mem.Allocator.Error.OutOfMemory) {
                    @panic("[-] Buy more RAM yo, lol\n");
                }
                std.debug.print("[-] Caught and error", .{});
                continue;
            };
            const name = try dir.realpathAlloc(allocator, val.name);
            const tf = TermFreq.from(tf_map);
            try self.map.put(name, tf);
        }
    }

    /// This function will index directory path
    pub fn index(self: *Self, directory: []const u8) !void {
        var dir = try std.fs.cwd().openDir(directory, .{ .iterate = true });
        defer dir.close();

        std.debug.print("Parsing directory: {s} \n", .{directory});
        try self.index_recursive(dir);

        std.debug.print("\n--------------\n", .{});
        std.debug.print("Indexed: {d} files", .{self.map.capacity()});
    }

    pub fn print(self: Self) void {
        var tfi_iter = self.map.iterator();
        while (tfi_iter.next()) |e| {
            std.debug.print("{s}\n", .{e.key_ptr.*});
        }
    }

    pub fn serializeJson(self: Self, jw: anytype) !void {
        try jw.beginObject();
        var tfi_iter = self.map.iterator();
        while (tfi_iter.next()) |e| {
            try jw.objectField(e.key_ptr.*);
            try e.value_ptr.*.serializeJson(jw);
        }
        try jw.endObject();
    }

    /// Search term will return a file path to that directory and the weight it already sorted
    /// It memory managed by [`TermFreqIndex`] as long this still exist
    /// the data still valid
    pub fn search(self: *Self, term: []const u8) !std.ArrayList(SearchResult) {
        const allocator = self.arena.allocator();

        var result = std.ArrayList(SearchResult).init(allocator);
        var count: u32 = 0;

        var tfi_iter = self.map.iterator();
        while (tfi_iter.next()) |e| {
            if (e.value_ptr.search(term) != 0) {
                count += 1;
            }
        }

        const count_float: f32 = @floatFromInt(count);
        const total: f32 = @floatFromInt(self.map.capacity());

        var tfi_iter0 = self.map.iterator();
        while (tfi_iter0.next()) |e| {
            const weight: f32 = @floatFromInt(e.value_ptr.*.search(term));
            if (weight == 0) continue;

            const sum: f32 = @floatFromInt(e.value_ptr.*.sum());
            const weight_result = (weight / sum) * std.math.log10(total / count_float);
            const search_result = SearchResult.init(
                e.key_ptr.*,
                weight_result,
            );
            try result.append(search_result);
        }

        std.mem.sort(SearchResult, result.items, {}, SearchResult.compareAsc);

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }
};

pub const SearchResult = struct {
    filepath: []const u8,
    weight: f32,

    const Self = @This();

    pub fn init(filepath: []const u8, weight: f32) Self {
        return Self{
            .filepath = filepath,
            .weight = weight,
        };
    }

    pub fn compareAsc(context: void, lhs: Self, rhs: Self) bool {
        _ = context;
        return lhs.weight > rhs.weight;
    }

    pub fn print(self: Self) void {
        std.debug.print("{s} -> {d}\n", .{ std.fs.path.basename(self.filepath), self.weight });
    }
};
