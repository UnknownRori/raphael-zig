const std = @import("std");
const testing = std.testing;

const Lexer = @import("./lexer.zig").Lexer;
const end_line = @import("./utils/utils.zig").end_line;
const read_file = @import("./utils/utils.zig").fs.read_file;

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

    pub fn parse(allocator: Allocator, contents: []const u8) !Self {
        var tf_map = std.StringHashMap(u32).init(allocator);

        var lexer = Lexer.init(contents);
        while (lexer.next()) |item| {
            const token = try std.ascii.allocUpperString(allocator, item);
            if (tf_map.contains(token)) {
                const entry = tf_map.getEntry(token).?;
                entry.value_ptr.* += @as(u32, 1);
                continue;
            }
            _ = try tf_map.getOrPutValue(token, 1);
        }

        return Self{
            .map = tf_map,
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

    pub fn getOr(self: Self, token: []const u8, default: u32) u32 {
        const value = self.map.get(token);
        if (value == null) return default;
        return value.?;
    }

    pub fn contains(self: Self, token: []const u8) bool {
        const value = self.map.get(token);
        if (value == null) return false;
        return true;
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
            var tf_map = TermFreq.init(allocator);
            for (value.object.keys(), value.object.values()) |key_tf, value_tf| {
                const term = try allocator.dupe(u8, key_tf);

                try tf_map.map.put(term, @intCast(value_tf.integer));
            }

            const name = try allocator.dupe(u8, key);
            try tfi.map.put(name, tf_map);
        }
        return tfi;
    }

    /// This function will index [`Dir`]
    pub fn index_recursive(self: *Self, dir: std.fs.Dir) !void {
        const allocator = self.arena.allocator();

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
            const file = try read_file(allocator, dir, val.name);

            const tf_map = TermFreq.parse(allocator, file) catch |err| {
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

        var tfi_iter = self.map.iterator();
        const term_uppercase = try std.ascii.allocUpperString(allocator, term);
        defer allocator.free(term_uppercase);
        while (tfi_iter.next()) |e| {
            var lexer = Lexer.init(term_uppercase);
            var rank: f32 = 0;

            while (lexer.next()) |token| {
                rank += tf(e.value_ptr.*, token) * idf(self.*, token);
            }

            // We don't give a frick with infinite rank like ur mom
            if (std.math.isInf(rank) or std.math.isNan(rank) or rank <= 0) continue;

            try result.append(SearchResult.init(e.key_ptr.*, rank));
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
        std.debug.print("{s} -> %{d:.2} ({d})\n", .{ std.fs.path.basename(self.filepath), self.weight * 1000, self.weight });
    }
};

fn tf(tf_table: TermFreq, term: []const u8) f32 {
    const a: f32 = @floatFromInt(tf_table.getOr(term, 0));
    const b: f32 = @floatFromInt(tf_table.sum());
    return a / b;
}

fn idf(idf_table: TermFreqIndex, term: []const u8) f32 {
    const a: f32 = @floatFromInt(idf_table.map.count());
    var count: u32 = 0;

    var tfi_iter = idf_table.map.iterator();
    while (tfi_iter.next()) |e| {
        if (e.value_ptr.contains(term)) {
            count += 1;
        }
    }

    const count_float: f32 = @floatFromInt(count);
    return std.math.log10((a / count_float));
}
