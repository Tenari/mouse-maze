const std = @import("std");
const User = @import("user.zig");

const Self = @This();

const Kind = enum {
    snake, zombie
};

// fields
x: usize = 0,
y: usize = 0,
kind: Kind = .snake,
target: u64 = 0,

pub fn init(x: usize, y: usize, uid: u64) Self {
    return .{
        .x = x,
        .y = y,
        .target = uid,
    };
}

