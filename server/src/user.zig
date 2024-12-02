const std = @import("std");
const zap = @import("zap");

pub const NameType = [64:0]u8;
const Self = @This();

pub const Printable = struct {
    id: u64,
    name: []const u8,
    x: usize,
    y: usize,
};

// fields
id: u64,
name: NameType,
name_len: u8,
pw_hash: [64]u8,
salt: [16]u8,
x: usize = 29,
y: usize = 20,

// fns
pub fn init(n: []const u8, pw: []const u8) Self {
    var name = [_:0]u8 { 0 } ** 64;
    std.mem.copyForwards(u8, &name, n);
    var hash = [_]u8 { 0 } ** 64;
    const salt = [_]u8{1,2,3,4}**4;
    std.mem.copyForwards(u8, &hash, &std.crypto.pwhash.bcrypt.bcrypt(pw, salt, .{ .rounds_log = 4}));
    var i: u8 = 0;
    for (n) |char| {
        if (char == 0) break;
        i += 1;
    }
    return .{
        .id = Self.nameToId(name),
        .name = name,
        .name_len = i,
        .pw_hash = hash,
        .salt = salt,
    };
}

pub fn nameToId(name: NameType) u64 {
    var i: u8 = 0;
    for (name) |char| {
        if (char == 0) break;
        i += 1;
    }
    return std.hash.Wyhash.hash(1234, name[0..i]) % 1000000;
}

pub fn checkPw(self: Self, pw: []const u8) bool {
    var hash = [_]u8 { 0 } ** 64;
    std.mem.copyForwards(u8, &hash, &std.crypto.pwhash.bcrypt.bcrypt(pw, self.salt, .{ .rounds_log = 4}));
    return std.mem.eql(u8, &hash, &self.pw_hash);
}

pub fn toPrintable(self: *Self) Printable {
    return .{
        .id = self.id,
        .name = self.name[0..self.name_len],
        .x = self.x,
        .y = self.y,
    };
}

pub fn print(self: *Self, buf: []u8) []const u8 {
    if (zap.stringifyBuf(buf, self.toPrintable(), .{})) |result| {
        return result;
    } else {
        return "null";
    }
}
