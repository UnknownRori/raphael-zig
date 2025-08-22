const fs = @import("./fs.zig");

pub fn end_line() []const u8 {
    const os = @import("builtin").os;
    if (os.tag == .windows) {
        return "\r\n";
    } else if (os.tag == .linux) {
        return "\n";
    }
    @panic("Unknown OS");
}
