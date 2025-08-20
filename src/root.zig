const std = @import("std");
const testing = std.testing;

fn end_line() []const u8 {
    const os = @import("builtin").os;
    if (os.tag == .windows) {
        return "\r\n";
    } else if (os.tag == .linux) {
        return "\n";
    }
    @panic("Unknown OS");
}

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn parse(self: Self, contents: []const u8) std.mem.Allocator.Error!TermFreq {
        var tf = TermFreq.init(self.allocator);

        var lines_sequence = std.mem.tokenizeSequence(u8, contents, "\n");
        while (lines_sequence.next()) |line| {
            var line_sequence = std.mem.tokenizeSequence(u8, line, " ");
            while (line_sequence.next()) |word| {
                const trimmed = std.mem.trim(u8, word, "\"");

                if (tf.map.contains(trimmed)) {
                    const a = tf.map.getEntry(trimmed).?;
                    a.value_ptr.* += @as(u32, 1);
                    continue;
                }
                _ = try tf.map.getOrPutValue(trimmed, 1);
            }
        }
        return tf;
    }
};

pub const TermFreq = struct {
    map: std.StringHashMap(u32),
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .map = std.StringHashMap(u32).init(allocator),
            .allocator = allocator,
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

    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }
};

pub const TermFreqIndex = struct {
    map: std.StringHashMap(TermFreq),
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .map = std.StringHashMap(TermFreq).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn from(map: std.StringHashMap(TermFreq)) Self {
        return Self{
            .map = map,
            .allocator = map.allocator,
        };
    }

    pub fn index(self: *Self, directory: []const u8) !void {
        var dir = try std.fs.cwd().openDir(directory, .{ .iterate = true });
        defer dir.close();

        const lexer = Lexer.init(self.allocator);

        var it = dir.iterate();
        while (try it.next()) |val| {
            // Skip non md file
            // TODO : Make it work with .txt too and recursively
            if (!std.mem.containsAtLeast(u8, val.name, 1, ".md") or val.kind != .file) {
                continue;
            }

            // TODO: MEM LEAK
            const file = try dir.readFileAlloc(self.allocator, val.name, 4096);

            const tf = lexer.parse(file) catch |err| {
                if (err == std.mem.Allocator.Error.OutOfMemory) {
                    @panic("[-] Buy more RAM yo, lol\n");
                }
                std.debug.print("[-] Caught and error", .{});
                continue;
            };
            std.debug.print("----- {s} -----\n", .{val.name});
            const name = try self.allocator.dupe(u8, val.name);
            try self.map.put(name, tf);
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

    pub fn deinit(self: *Self) void {
        var tfi_iter = self.map.iterator();
        while (tfi_iter.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            e.value_ptr.*.deinit();
        }
        self.map.deinit();
    }
};
