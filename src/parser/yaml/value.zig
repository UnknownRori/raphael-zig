const std = @import("std");

const String = std.ArrayList(u8);

pub const Value = union(enum) {
    Scalar: struct {
        key: String,
        value: String,
    },
    Sequence: struct {
        key: String,
        value: std.ArrayList(String),
    },
    Mapping: std.StringArrayHashMap(*Value),
};
