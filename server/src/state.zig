const std = @import("std");
const zap = @import("zap");
const User = @import("user.zig");
const Tile = @import("tile.zig");
const consts = @import("constants.zig");
const MAP_HEIGHT = consts.MAP_HEIGHT;
const MAP_LENGTH = consts.MAP_LENGTH;

const Self = @This();

const UserMap = std.AutoHashMap(u64, User);
const Hash = std.crypto.hash.sha2.Sha256;
const Token = [Hash.digest_length * 2]u8;

const Printable = struct {
    map: [MAP_HEIGHT][MAP_LENGTH]Tile,
    users: []User.Printable,
    round: u8,
};

const Direction = enum(u8) { north = 110, south = 115, east = 101, west = 119, };

// fields
alloc: std.mem.Allocator = undefined,
users: UserMap = undefined,
user_lock: std.Thread.Mutex = .{},
sessions: std.StringHashMap(u64) = undefined, // str -> user id
session_lock: std.Thread.Mutex = .{},
token_name: []const u8 = "gc_token",
map: [MAP_HEIGHT][MAP_LENGTH]Tile,
main_lock: std.Thread.Mutex = .{},
round: u8 = 1,

// fns
pub fn init(alloc: std.mem.Allocator) !Self {
    return .{
        .alloc = alloc,
        .users = UserMap.init(alloc),
        .sessions = std.StringHashMap(u64).init(alloc),
        .map = try generateMaze(MAP_LENGTH, MAP_HEIGHT, alloc),
    };
}

fn randomTile(comptime len: usize, comptime height: usize, random: std.Random, map: *[height][len]Tile) *Tile {
    const x = ((random.int(usize) % @divFloor(len, 2)) * 2) + 1;
    const y = ((random.int(usize) % @divFloor(height, 2)) * 2) + 1;
    return &map[y][x];
}

fn neighbors(comptime len: usize, comptime height: usize, map: *[height][len]Tile, tile: *Tile) [4]?*Tile {
    var final: [4]?*Tile = [_]?*Tile {null} ** 4;
    if (tile.y != 0 and tile.y != 1) {
        final[0] = &map[tile.y - 2][tile.x];
    }
    if (tile.y + 2 < height) {
        final[1] = &map[tile.y + 2][tile.x];
    }
    if (tile.x != 0 and tile.x != 1) {
        final[2] = &map[tile.y][tile.x - 2];
    }
    if (tile.x + 2 < len) {
        final[3] = &map[tile.y][tile.x + 2];
    }
    return final;
}

// true if there's still stone on an odd-indexed grid-location, false otherwise
fn incomplete(comptime len: usize, comptime height: usize, map: *[height][len]Tile) bool {
    for (0..height) |y| {
        for (0..len) |x| {
            if (x % 2 == 1 and y % 2 == 1 and map[y][x].kind == .stone) {
                return true;
            }
        }
    }
    return false;
}

fn generateMaze(comptime len: usize, comptime height: usize, alloc: std.mem.Allocator) ![height][len]Tile {
    var prng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();
    var map: [height][len]Tile = undefined;
    for (0..len) |x| {
        for (0..height) |y| {
            map[y][x] = Tile.init(x,y);
        }
    }
    // first open up a random cell
    var first = randomTile(len, height, random, &map);
    first.kind = .grass;
    // then choose another tile to start from and start finding a path between the two
    var path = std.ArrayList(*Tile).init(alloc);
    defer path.deinit();
    while (incomplete(len, height, &map)) {
        path.shrinkRetainingCapacity(0);

        var start = randomTile(len, height, random, &map);
        // ensure the start of this path is currently "blank" ie .stone
        while (start.kind != .stone) {
            start = randomTile(len, height, random, &map);
        }
        try path.append(start);
        start.kind = .exit;
        while (path.items[path.items.len - 1].kind != .grass) {
            const last = path.items[path.items.len - 1];
            const neighs = neighbors(len, height, &map, last);
            var next = neighs[random.int(usize) % 4];
            while (next == null) {
                next = neighs[random.int(usize) % 4];
            }
            try path.append(next.?);
            // mark the intermediate-neighbor as an exit to indicate that it's also on the path
            map[(last.y + next.?.y) / 2][(last.x + next.?.x) / 2].kind = .exit;
            // if `next` is already in our maze, the path is finished, so add it to the maze
            const is_in_maze: bool = next.?.kind == .grass;
            if (is_in_maze) {
                // mark all 'exit' tiles as grass, since we were using exit as a temporary pathing placeholder type
                for (0..len) |x| {
                    for (0..height) |y| {
                        if (map[y][x].kind == .exit) {
                            map[y][x].kind = .grass;
                        }
                    }
                }
                continue;
            }
            
            // we're not done so we go ahead and mark the `next` as part of our path
            map[next.?.y][next.?.x].kind = .exit;
            // now check if we made a loop:
            var previous_index: usize = 0;
            for (path.items, 0..) |item, i| {
                if (item == next.?) {
                    previous_index = i;
                    break;
                }
            }
            // if `next` is already in our path, it's a loop, so erase the loop
            if (previous_index != path.items.len - 1) {
                for (path.items[previous_index+1..], 0..) |loop_cell, i| {
                    // clear the loop_cell
                    if (loop_cell != next.?) {
                        loop_cell.kind = .stone;
                    }
                    // un-mark the intermediate-neighbor as an exit
                    const prev = path.items[previous_index+i];
                    map[(loop_cell.y + prev.y) / 2][(loop_cell.x + prev.x) / 2].kind = .stone;
                }
                path.shrinkRetainingCapacity(previous_index+1);
            }
        }
    }
    map[0][1].kind = .exit;
    map[height - 1][len - 2].kind = .grass;
    map[height - 1][len - 2].hidden = false;

    for (0..height) |y| {
        for (0..len) |x| {
            const north = getTileCheckedFromMap(MAP_HEIGHT, MAP_LENGTH, &map, x, y, .north);
            const south = getTileCheckedFromMap(MAP_HEIGHT, MAP_LENGTH, &map, x, y, .south);
            const east = getTileCheckedFromMap(MAP_HEIGHT, MAP_LENGTH, &map, x, y, .east);
            const west = getTileCheckedFromMap(MAP_HEIGHT, MAP_LENGTH, &map, x, y, .west);
            var surroundingStoneCount: u8 = 0;
            if (north != null and north.?.kind == .stone) {
                surroundingStoneCount += 1;
            }
            if (south != null and south.?.kind == .stone) {
                surroundingStoneCount += 1;
            }
            if (east != null and east.?.kind == .stone) {
                surroundingStoneCount += 1;
            }
            if (west != null and west.?.kind == .stone) {
                surroundingStoneCount += 1;
            }
            if (surroundingStoneCount == 3 and map[y][x].kind != .stone) {
                switch (random.intRangeAtMost(u8, 0, 2)) {
                    0 => {
                        map[y][x].gold = random.intRangeAtMost(u8, 1, 8);
                    },
                    1 => {
                        map[y][x].gold = random.intRangeAtMost(u8, 7, 16);
                        map[y][x].chest = true;
                        map[y][x].trapped = random.intRangeAtMost(u8, 0, 2) == 0;
                    },
                    else => {},
                }
            }
        }
    }
    return map;
}

pub fn reset(self: *Self) void {
    self.main_lock.lock();
    defer self.main_lock.unlock();
    self.map = generateMaze(MAP_LENGTH, MAP_HEIGHT, self.alloc) catch self.map;
    {
        self.user_lock.lock();
        defer self.user_lock.unlock();
        var it = self.users.keyIterator();
        while (it.next()) |key| {
            if (self.users.getPtr(key.*)) |user| {
                user.x = consts.DEFAULT_X;
                user.y = consts.DEFAULT_Y;
                user.banked += user.gold;
                user.gold = 0;
                user.hearts = 3;
                user.exited = false;
            }
        }
    }
}

pub fn deinit(self: *Self) void {
    self.users.deinit();
    var iter = self.sessions.keyIterator();
    while (iter.next()) |key_str| {
        self.alloc.free(key_str.*);
    }
    self.sessions.deinit();
}

pub fn addUser(self: *Self, user: User) !void {
    if (self.users.contains(user.id)) {
        return error.UsernameAlreadyTaken;
    } else {
        self.user_lock.lock();
        defer self.user_lock.unlock();
        try self.users.put(user.id, user);
    }
}

pub fn userFromToken(self: *Self, token: []const u8) ?*User {
    // locked or unlocked token lookup
    self.session_lock.lock();
    defer self.session_lock.unlock();
    if (self.sessions.get(token)) |userid| {
        std.debug.print("sessions.get(token): {d}\n", .{userid});
        // cookie is a valid session!
        if (self.users.getPtr(userid)) |user| {
            return user;
        }
        // the `else` case here actually shouldn't happen,
        // since it represents a valid token without a matching user,
        // but I'm fine treating it as if it were just an invalid token
    }
    // unmatching cookie
    // this is not necessarily a bad thing. it could be a
    // stale cookie from a previous session. So let's check
    // if username and password are being sent and correct.
    return null;
}

pub fn createSession(self: *Self, username: User.NameType) ![]const u8 {
    var hasher = Hash.init(.{});
    hasher.update(&username);
    var buf: [16]u8 = undefined;
    const time_nano = std.time.nanoTimestamp();
    const timestampHex = try std.fmt.bufPrint(&buf, "{0x}", .{time_nano});
    hasher.update(timestampHex);

    var digest: [Hash.digest_length]u8 = undefined;
    hasher.final(&digest);
    const token: Token = std.fmt.bytesToHex(digest, .lower);
    const token_str = try self.alloc.dupe(u8, token[0..token.len]);

    self.session_lock.lock();
    defer self.session_lock.unlock();

    if (!self.sessions.contains(token_str)) {
        try self.sessions.put(try self.alloc.dupe(u8, token_str), User.nameToId(username));
    }
    return token_str;
}

pub fn writeMapJson(self: *Self, buf: []u8) ?[]const u8 {
    return zap.stringifyBuf(buf, self.map, .{});
}

pub fn writeJson(self: *Self, buf: []u8) []const u8 {
    var iter = self.users.valueIterator();
    var users = std.ArrayList(User.Printable).init(self.alloc);
    defer users.deinit();
    while (iter.next()) |item| {
        users.append(item.toPrintable()) catch return "null";
    }
    if (zap.stringifyBuf(buf, Printable {
        .users = users.items,
        .map = self.map,
        .round = self.round,
    }, .{})) |result| {
        return result;
    } else {
        return "null";
    }
}

fn attemptToOpenChest(user: *User, tile: *Tile) void {
    if (tile.trapped) {
        user.takeDamage(1);
        tile.trapped = false;
        tile.exploded_at = std.time.timestamp() * 1000;
    } else {
        tile.chest = false;
    }
}

pub fn move(self: *Self, user: *User, direction: [1]u8) !void {
    defer {
        if (self.isGameFinished()) {
            self.round += 1;
            self.reset();
        }
    }
    if (self.round == 4 or user.exited or user.hearts == 0) {
        return;
    }
    self.main_lock.lock();
    defer self.main_lock.unlock();
    if (direction[0] == 111) { // 'o'
        const maybe_north = self.getTileChecked(user.x, user.y, .north);
        const maybe_south = self.getTileChecked(user.x, user.y, .south);
        const maybe_east = self.getTileChecked(user.x, user.y, .east);
        const maybe_west = self.getTileChecked(user.x, user.y, .west);
        if (maybe_north != null and maybe_north.?.kind == .grass and maybe_north.?.chest) {
            attemptToOpenChest(user, maybe_north.?);
        } else if (maybe_south != null and maybe_south.?.kind == .grass and maybe_south.?.chest) {
            attemptToOpenChest(user, maybe_south.?);
        } else if (maybe_east != null and maybe_east.?.kind == .grass and maybe_east.?.chest) {
            attemptToOpenChest(user, maybe_east.?);
        } else if (maybe_west != null and maybe_west.?.kind == .grass and maybe_west.?.chest) {
            attemptToOpenChest(user, maybe_west.?);
        }
        return;
    }

    const new_tile = self.getTileChecked(user.x, user.y, @enumFromInt(direction[0]));
    if (new_tile) |tile| {
        // un-hide the tiles you can see
        self.unhideVisibleHalls(tile.x, tile.y);
        switch (tile.kind) {
            .grass => {
                if (tile.chest) {
                    return; // you can't move when there's a chest there
                }
                // update the user
                user.x = tile.x;
                user.y = tile.y;
                // un-hide the tile
                tile.hidden = false;
                if (tile.gold > 0 and !tile.chest) {
                    user.gold += tile.gold;
                    tile.gold = 0;
                }
            },
            .exit => {
                user.exited = true;
            },
            .stone => {},// don't need to do anything else... they cant move
        }
    }
}

fn isGameFinished(self: *Self) bool {
    var finished: bool = true;
    {
        self.user_lock.lock();
        defer self.user_lock.unlock();
        var it = self.users.valueIterator();
        while (it.next()) |user| {
            if (!user.exited and user.hearts > 0) {
                finished = false;
            }
        }
    }
    return finished;
}

fn getTileCheckedFromMap(
    comptime height: usize,
    comptime len: usize,
    map: *[height][len]Tile,
    x: u64,
    y: u64,
    direction: Direction
) ?*Tile {
    if (direction == .north and y > 0) {
        return &map[y-1][x];
    }
    if (direction == .south and y < MAP_HEIGHT - 1) {
        return &map[y+1][x];
    }
    if (direction == .west and x > 0) {
        return &map[y][x-1];
    }
    if (direction == .east and x < MAP_LENGTH - 1) {
        return &map[y][x+1];
    }
    return null;
}

fn getTileChecked(self: *Self, x: u64, y: u64, direction: Direction) ?*Tile {
    return getTileCheckedFromMap(MAP_HEIGHT, MAP_LENGTH, &self.map, x, y, direction);
}

// in a 5 tile-radius, mark everything not blocked by a wall as hidden=false
fn unhideVisibleHalls(self: *Self, x: u64, y: u64) void {
    self.unhideDirection(x, y, .north);
    self.unhideDirection(x, y, .south);
    self.unhideDirection(x, y, .east);
    self.unhideDirection(x, y, .west);
}

fn unhideDirection(self: *Self, x: u64, y: u64, direction: Direction) void {
    var current_tile = &self.map[y][x];
    var iterations: usize = 0;
    while (current_tile.kind != .stone and iterations < 5) {
        const maybe_tile = self.getTileChecked(current_tile.x, current_tile.y, direction);
        if (maybe_tile) |tile| {
            current_tile = tile;
        }
        current_tile.hidden = false;
        iterations += 1;
    }
}

