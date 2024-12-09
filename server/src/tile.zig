const std = @import("std");
const zap = @import("zap");

const Self = @This();

const TileKind = enum {
    grass, stone, exit
};

// fields
x: usize,
y: usize,
kind: TileKind = .stone,
hidden: bool = true,
gold: u8 = 0,
chest: bool = false,
trapped: bool = false,
exploded_at: i64 = 0,

// fns
pub fn init(x: usize, y: usize) Self {
    return .{
        .x = x,
        .y = y,
    };
}

pub fn print(self: *Self, buf: []u8) []const u8 {
    if (zap.stringifyBuf(buf, self, .{})) |json| {
        return json;
    } else {
        return "null";
    }
}
