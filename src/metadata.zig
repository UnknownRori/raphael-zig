const std = @import("std");

const String = std.ArrayList(u8);
const Allocator = std.mem.Allocator;

const Error = error{
    InvalidDescription,
    InvalidTag,
    OutOfMemory,
};

pub const MetaData = struct {
    tags: std.ArrayList(String),
    description: String,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .tags = try std.ArrayList(String).initCapacity(allocator, 10),
            .description = try String.initCapacity(allocator, 10),
            .allocator = allocator,
        };
    }

    pub fn serializeJson(self: Self, jw: anytype) !void {
        try jw.beginObject();
        try jw.objectField("description");
        try jw.write(self.description.items);
        try jw.objectField("tags");
        try jw.beginArray();
        for (self.tags.items) |item| {
            try jw.write(item.items);
        }
        try jw.endArray();

        try jw.endObject();
    }

    pub fn deserializeJson(allocator: Allocator, object: std.json.ObjectMap) Error!Self {
        var self = try Self.init(allocator);

        const description = object.get("description");
        if (description == null) {
            return Error.InvalidDescription;
        }
        try self.description.appendSlice(allocator, description.?.string);

        const tags = object.get("tags");
        if (tags == null) {
            return Error.InvalidTag;
        }
        for (tags.?.array.items) |item| {
            var str = try String.initCapacity(allocator, item.string.len);
            try str.appendSlice(allocator, item.string);
            try self.tags.append(allocator, str);
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.tags.items) |item| {
            item.deinit(self.allocator);
        }
        self.tags.deinit(self.allocator);
        self.description.deinit(self.allocator);
    }
};
