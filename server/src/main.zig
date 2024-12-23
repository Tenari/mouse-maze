const std = @import("std");
const zap = @import("zap");
const User = @import("user.zig");
const State = @import("state.zig");
const Ws = @import("ws.zig");
const MOVES_PER_USER = @import("constants.zig").MOVES_PER_USER;

const PORT = 3334;
const FPS: i128 = 1;
const GOAL_LOOP_TIME: i128 = std.time.ns_per_s / FPS;

// GLOBALS
var state: State = undefined;
var routes: std.StringHashMap(Route) = undefined;
var ws_manager: Ws.ChannelManager = undefined;

// just a way to share our allocator via callback
const SharedAllocator = struct {
    // static
    var allocator: std.mem.Allocator = undefined;

    const Self = @This();

    // just a convenience function
    pub fn init(a: std.mem.Allocator) void {
        allocator = a;
    }

    // static function we can pass to the listener later
    pub fn getAllocator() std.mem.Allocator {
        return allocator;
    }
};

const Session = struct {
    user: *User = undefined,
    token: []const u8 = undefined,
};

const RequestFn = *const fn (r: zap.Request, session: ?Session) void;
const Route = struct {
    get: ?RequestFn = null,
    post: ?RequestFn = null,
    put: ?RequestFn = null,
};

fn setupRoutes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(Route).init(a);
    try routes.put("/user", .{
        .get = getUser,
        .post = createOrLoginUser,
    });
    try routes.put("/state", .{
        .get = getState,
        .post = submitMove,
    });
    try routes.put("/map", .{
        .get = getMap,
        .post = resetGame,
    });
}

fn getUser(r: zap.Request, session: ?Session) void {
    if (session) |*sess| {
        var buf: [1024]u8 = undefined;
        const message = sess.user.print(&buf);
        r.sendJson(message) catch return;
    } else {
        r.sendJson("{\"error\":\"You must be logged in\"}") catch return;
    }
}

fn createOrLoginUser(r: zap.Request, session: ?Session) void {
    if (session != null) {
        return r.sendJson("{\"error\":\"already logged in\"}") catch return;
    }
    r.parseBody() catch |err| {
        std.log.err("Parse Body error: {any}. Expected if body is empty", .{err});
    };
    r.parseQuery();

    var name: User.NameType = [_:0]u8 {0} ** 64;
    if (r.getParamStr(SharedAllocator.getAllocator(), "name", false)) |val| {
        if (val) |*str| {
            defer str.deinit();
            std.mem.copyForwards(u8, &name, str.str);
        } else {
            return r.sendJson("{\"error\":\"missing `name` parameter\"}") catch return;
        }
    } else |_| {
        return r.sendJson("{\"error\":\"missing `name` parameter\"}") catch return;
    }

    var pw = [_]u8 {0}**64;
    if (r.getParamStr(SharedAllocator.getAllocator(), "pw", false)) |val| {
        if (val) |*str| {
            defer str.deinit();
            std.mem.copyForwards(u8, &pw, str.str);
        } else {
            return r.sendJson("{\"error\":\"missing `pw` parameter\"}") catch return;
        }
    } else |_| {
        return r.sendJson("{\"error\":\"missing `pw` parameter\"}") catch return;
    }

    if (state.getUserByName(name)) |user| {
        // log them in
        if (user.checkPw(&pw)) {
            const token = state.createSession(user.name, user.id) catch {
                r.sendJson("{\"error\":\"could not login user?\"}") catch return;
                return;
            };
            defer state.alloc.free(token);
            if (r.setCookie(.{
                .name = state.token_name,
                .value = token,
                .max_age_s = 0,
            })) {
                var buf: [1024]u8 = undefined;
                const message = user.print(&buf);
                return r.sendJson(message) catch return;
            } else |err| {
                zap.debug("could not set session token: {any}", .{err});
                return r.sendJson("{\"error\":\"could not log in\"}") catch return;
            }
        } else {
            return r.sendJson("{\"error\":\"incorrect password\"}") catch return;
        }
    } else {
        // create the user
        var user = User.init(&name, &pw, state.users.items.len);
        state.addUser(user) catch |e| {
            zap.debug("could not add user: {any}", .{e});
            return r.sendJson("{\"error\":\"could not add user?\"}") catch return;
        };
        const token = state.createSession(user.name, user.id) catch {
            return r.sendJson("{\"error\":\"could not login user?\"}") catch return;
        };
        defer state.alloc.free(token);
        if (r.setCookie(.{
            .name = state.token_name,
            .value = token,
            .max_age_s = 0,
            .secure = false,
        })) {
            var buf: [1024*32*4]u8 = undefined;
            const json_to_send: []const u8 = state.writeJson(&buf);
            Ws.Handler.publish(.{ .channel = "state", .message = json_to_send });
            var buf2: [1024]u8 = undefined;
            const message = user.print(&buf2);
            return r.sendJson(message) catch return;
        } else |err| {
            zap.debug("could not set session token: {any}", .{err});
            return r.sendJson("{\"error\":\"could not log in\"}") catch return;
        }
    }
}

fn getMap(r: zap.Request, _: ?Session) void {
    var buf: [1024*8]u8 = undefined;
    var json_to_send: []const u8 = undefined;
    if (state.writeMapJson(&buf)) |json| {
        json_to_send = json;
    } else {
        json_to_send = "null";
    }
    std.debug.print("<< json: {s}\n", .{json_to_send});
    r.sendBody(json_to_send) catch return;
}

fn getState(r: zap.Request, _: ?Session) void {
    var buf: [1024*32*4]u8 = undefined;
    const json_to_send: []const u8 = state.writeJson(&buf);
    r.sendBody(json_to_send) catch return;
}

fn submitMove(r: zap.Request, session: ?Session) void {
    if (session) |sess| {
        r.parseBody() catch |err| {
            std.log.err("Parse Body error: {any}. Expected if body is empty", .{err});
        };
        r.parseQuery();

        var direction: [1]u8 = [1]u8{0};
        if (r.getParamStr(SharedAllocator.getAllocator(), "direction", false)) |val| {
            if (val) |*str| {
                defer str.deinit();
                std.mem.copyForwards(u8, &direction, str.str);
            } else {
                return r.sendJson("{\"error\":\"missing `direction` parameter\"}") catch return;
            }
        } else |_| {
            return r.sendJson("{\"error\":\"missing `direction` parameter\"}") catch return;
        }

        if (state.move(sess.user, direction)) {
            var buf: [1024*32*4]u8 = undefined;
            const json_to_send: []const u8 = state.writeJson(&buf);
            Ws.Handler.publish(.{ .channel = "state", .message = json_to_send });
            r.sendBody(json_to_send) catch return;
        } else |e| switch (e) {
            error.NotEnoughCheese => return r.sendJson("{\"error\":\"not enough cheeses collected\"}") catch return,
        }
    } else {
        return r.sendJson("{\"error\":\"you're not logged in\"}") catch return;
    }
}

fn resetGame(r: zap.Request, session: ?Session) void {
    if (session == null) {
        return r.sendJson("{\"error\":\"you're not logged in\"}") catch return;
    }
    state.reset();
    var buf: [1024*32*4]u8 = undefined;
    const json_to_send: []const u8 = state.writeJson(&buf);
    Ws.Handler.publish(.{ .channel = "state", .message = json_to_send });
    return r.sendJson("{\"status\":\"reset\"}") catch return;
}

fn onRequest(r: zap.Request) void {
    const alloc = SharedAllocator.getAllocator();

    // parse session cookie
    var session: ?Session = null;
    r.parseCookies(false);
    if (r.getCookieStr(alloc, state.token_name, false)) |maybe_cookie| {
        if (maybe_cookie) |cookie| {
            defer cookie.deinit();
            if (state.userFromToken(cookie.str)) |user| {
                session = Session {
                    .token = cookie.str,
                    .user = user,
                };
            } else {
                zap.debug("Auth: COOKIE IS BAD!!!!: {s}\n", .{cookie.str});
            }
        }
    } else |err| {
        zap.debug("unreachable: could not check for cookie in UserPassSession: {any}", .{err});
    }

    // dumbass routing
    if (r.path) |p| {
        if (routes.get(p)) |route| {
            switch (r.methodAsEnum()) {
                .GET => if (route.get) |func| {
                    return func(r, session);
                },
                .POST => if (route.post) |func| {
                    return func(r, session);
                },
                .PUT => if (route.put) |func| {
                    return func(r, session);
                },
                else => {}
            }
        }
    }

    // fallback 404 response here
    r.setStatus(.not_found);
    r.sendBody(
        \\ <html><body>
        \\ <h1>Error 404 - Not Found</h1>
        \\ </body></html>
    ) catch return;
}

fn on_upgrade(r: zap.Request, target_protocol: []const u8) void {
    // make sure we're talking the right protocol
    if (!std.mem.eql(u8, target_protocol, "websocket")) {
        std.log.warn("received illegal protocol: {s}", .{target_protocol});
        r.setStatus(.bad_request);
        r.sendBody("400 - BAD REQUEST") catch unreachable;
        return;
    }
    var channel = ws_manager.newChannel() catch |err| {
        std.log.err("Error creating context: {any}", .{err});
        return;
    };

    Ws.Handler.upgrade(r.h, &channel.settings) catch |err| {
        std.log.err("Error in websocketUpgrade(): {any}", .{err});
        return;
    };
    std.log.info("connection upgrade OK", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};

    // we start a block here so the defers will run before we call the gpa
    // to detect leaks
    {
        const allocator = gpa.allocator();
        SharedAllocator.init(allocator);

        try setupRoutes(allocator);
        defer routes.deinit();

        state = try State.init(allocator);
        defer state.deinit();

        ws_manager = Ws.ChannelManager.init(allocator, "state", "user-", &state);
        defer ws_manager.deinit();

        var listener = zap.HttpListener.init(
            .{
                .port = PORT,
                .on_request = onRequest,
                .on_upgrade = on_upgrade,
                .log = true,
                .max_clients = 10_000,
                .max_body_size = 1 * 1024,
                .public_folder = "src/ui",
            },
        );
        try listener.listen();

        zap.enableDebugLog();

        std.debug.print("server live at http://127.0.0.1:{d}\n", .{PORT});

        // spin off thread for the auto-occuring game actions
        const game_thread_handle = try std.Thread.spawn(
            .{},
            gameLoop,
            .{}
        );
        game_thread_handle.detach();

        // start worker threads
        zap.start(.{
            .threads = 1,
            .workers = 1,
        });
    }

    // all defers should have run by now
    std.debug.print("\n\nSTOPPED!\n", .{});
    const leaked = gpa.detectLeaks();
    std.debug.print("Leaks detected: {}\n", .{leaked});
}

fn gameLoop() void {
    var prng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();
    var buf: [1024*32*4]u8 = undefined;
    while (true) {
        const loop_start = std.time.nanoTimestamp();

        state.main_lock.lock();

        // if every user has moved MOVES_PER_USER spaces (on average), then we spawn the ai
        if (
            state.user_moves > 0
            and (state.user_moves / state.activeUserCount()) >= MOVES_PER_USER
        ) {
            state.user_moves = 0;// clear the move-count
            state.spawnMonster(random);
        }
        state.moveMonsters();

        const json_to_send: []const u8 = state.writeJson(&buf);
        Ws.Handler.publish(.{ .channel = "state", .message = json_to_send });
        state.main_lock.unlock();

        const loop_duration = std.time.nanoTimestamp() - loop_start;
        const remaining_time = GOAL_LOOP_TIME - loop_duration;
        if (remaining_time > 0) {
            std.time.sleep(@intCast(remaining_time));
        }
    }
}

