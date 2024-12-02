const std = @import("std");
const zap = @import("zap");
const User = @import("user.zig");
const State = @import("state.zig");

const PORT = 3333;

// GLOBALS
var state: State = undefined;
var routes: std.StringHashMap(Route) = undefined;

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

// create a combined context struct
const Context = struct {
    session: ?SessionMiddleWare.Session = null,
};

// we create a Handler type based on our Context
const Handler = zap.Middleware.Handler(Context);

const SessionMiddleWare = struct {
    handler: Handler,
    token_name: []const u8 = "gc_token",
    allocator: std.mem.Allocator,

    const Self = @This();

    // note: it MUST have all default values!!!
    const Session = struct {
        user: *User = undefined,
        token: []const u8 = undefined,
    };

    pub fn init(alloc: std.mem.Allocator, other: ?*Handler) Self {
        return .{
            .handler = Handler.init(onRequest, other),
            .allocator = alloc,
        };
    }

    // we need the handler as a common interface to chain stuff
    pub fn getHandler(self: *Self) *Handler {
        return &self.handler;
    }

    // note that the first parameter is of type *Handler, not *Self !!!
    pub fn onRequest(handler: *Handler, r: zap.Request, context: *Context) bool {
        // this is how we would get our self pointer
        const self: *Self = @fieldParentPtr("handler", handler);

        // check for session cookie
        r.parseCookies(false);
        if (r.getCookieStr(self.allocator, self.token_name, false)) |maybe_cookie| {
            if (maybe_cookie) |cookie| {
                defer cookie.deinit();
                if (state.userFromToken(cookie.str)) |user| {
                    zap.debug("Auth: COOKIE IS OK!!!!\n", .{});
                    context.session = Session {
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
        // continue in the chain
        return handler.handleOther(r, context);
    }
};

const RequestFn = *const fn (r: zap.Request, context: *Context) bool;
const Route = struct {
    get: ?RequestFn = null,
    post: ?RequestFn = null,
    put: ?RequestFn = null,
};

fn setup_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(Route).init(a);
    try routes.put("/static", .{
        .get = static_site,
    });
    try routes.put("/user", .{
        .get = get_user,
        .post = create_or_login_user,
    });
    try routes.put("/state", .{
        .get = get_state,
        .post = submit_move,
    });
    try routes.put("/map", .{
        .get = get_map,
    });
}

fn static_site(r: zap.Request, _: *Context) bool {
    r.sendBody("<html><body><h1>Hello from STATIC ZAP!</h1></body></html>") catch return false;
    return true;
}

fn get_user(r: zap.Request, c: *Context) bool {
    if (c.session) |*sess| {
        var buf: [1024]u8 = undefined;
        const message = sess.user.print(&buf);
        r.sendJson(message) catch unreachable;
        return true;
    } else {
        r.sendJson("{\"error\":\"You must be logged in\"}") catch return false;
        return true;
    }
}

fn create_or_login_user(r: zap.Request, c: *Context) bool {
    if (c.session) |_| {
        r.sendJson("{\"error\":\"already logged in\"}") catch return false;
        return true;
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
            r.sendJson("{\"error\":\"missing `name` parameter\"}") catch return false;
            return true;
        }
    } else |_| {
        r.sendJson("{\"error\":\"missing `name` parameter\"}") catch return false;
        return true;
    }

    var pw = [_]u8 {0}**64;
    if (r.getParamStr(SharedAllocator.getAllocator(), "pw", false)) |val| {
        if (val) |*str| {
            defer str.deinit();
            std.mem.copyForwards(u8, &pw, str.str);
        } else {
            r.sendJson("{\"error\":\"missing `pw` parameter\"}") catch return false;
            return true;
        }
    } else |_| {
        r.sendJson("{\"error\":\"missing `pw` parameter\"}") catch return false;
        return true;
    }

    if (state.users.getPtr(User.nameToId(name))) |user| {
        // log them in
        if (user.checkPw(&pw)) {
            const token = state.createSession(user.name) catch {
                r.sendJson("{\"error\":\"could not login user?\"}") catch return false;
                return true;
            };
            defer state.alloc.free(token);
            if (r.setCookie(.{
                .name = state.token_name,
                .value = token,
                .max_age_s = 0,
            })) {
                var buf: [1024]u8 = undefined;
                const message = user.print(&buf);
                r.sendJson(message) catch unreachable;
                return true;
            } else |err| {
                zap.debug("could not set session token: {any}", .{err});
                r.sendJson("{\"error\":\"could not log int\"}") catch return false;
                return true;
            }
        } else {
            r.sendJson("{\"error\":\"incorrect password\"}") catch return false;
            return true;
        }
    } else {
        // create the user
        var user = User.init(&name, &pw);
        state.addUser(user) catch |e| {
            zap.debug("could not add user: {any}", .{e});
            r.sendJson("{\"error\":\"could not add user?\"}") catch return false;
            return true;
        };
        const token = state.createSession(user.name) catch {
            r.sendJson("{\"error\":\"could not login user?\"}") catch return false;
            return true;
        };
        defer state.alloc.free(token);
        if (r.setCookie(.{
            .name = state.token_name,
            .value = token,
            .max_age_s = 0,
        })) {
            var buf: [1024]u8 = undefined;
            const message = user.print(&buf);
            r.sendJson(message) catch unreachable;
            return true;
        } else |err| {
            zap.debug("could not set session token: {any}", .{err});
            r.sendJson("{\"error\":\"could not log in\"}") catch return false;
            return true;
        }
    }
}

fn get_map(r: zap.Request, _: *Context) bool {
    var buf: [1024*8]u8 = undefined;
    var json_to_send: []const u8 = undefined;
    if (state.writeMapJson(&buf)) |json| {
        json_to_send = json;
    } else {
        json_to_send = "null";
    }
    std.debug.print("<< json: {s}\n", .{json_to_send});
    r.sendBody(json_to_send) catch return false;
    return true;
}

fn get_state(r: zap.Request, _: *Context) bool {
    var buf: [1024*32*4]u8 = undefined;
    const json_to_send: []const u8 = state.writeJson(&buf);
    r.sendBody(json_to_send) catch return false;
    return true;
}

fn submit_move(r: zap.Request, c: *Context) bool {
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
            r.sendJson("{\"error\":\"missing `direction` parameter\"}") catch return false;
            return true;
        }
    } else |_| {
        r.sendJson("{\"error\":\"missing `direction` parameter\"}") catch return false;
        return true;
    }

    var uid: u64 = 0;
    if (r.getParamStr(SharedAllocator.getAllocator(), "uid", false)) |val| {
        if (val) |*str| {
            defer str.deinit();
            std.debug.print("got the uid param\n", .{});
            uid = std.fmt.parseInt(u64, str.str, 10) catch return false;
        } else {
            r.sendJson("{\"error\":\"missing `uid` parameter\"}") catch return false;
            return true;
        }
    } else |_| {
        r.sendJson("{\"error\":\"missing `uid` parameter\"}") catch return false;
        return true;
    }
    std.log.err("we parsed the uid {d}", .{uid});
    if (state.users.getPtr(uid)) |user| {
        state.move(user, direction);
    }
    return get_state(r, c);
}

// handles the request and sends a response
const ApiMiddleWare = struct {
    handler: Handler,

    const Self = @This();

    pub fn init(other: ?*Handler) !Self {
        return .{
            .handler = Handler.init(onRequest, other),
        };
    }

    // we need the handler as a common interface to chain stuff
    pub fn getHandler(self: *Self) *Handler {
        return &self.handler;
    }

    // note that the first parameter is of type *Handler, not *Self !!!
    pub fn onRequest(handler: *Handler, r: zap.Request, context: *Context) bool {
        // dumbass routing
        if (r.path) |p| {
            if (routes.get(p)) |route| {
                switch (r.methodAsEnum()) {
                    .GET => if (route.get) |func| {
                        return func(r, context);
                    },
                    .POST => if (route.post) |func| {
                        return func(r, context);
                    },
                    .PUT => if (route.put) |func| {
                        return func(r, context);
                    },
                    else => {}
                }
            }
        }
        // TODO real 404 response here

        // this is how we would get our self pointer
        const self: *Self = @fieldParentPtr("handler", handler);
        _ = self;

        var buf: [1024]u8 = undefined;
        var sessionFound: bool = false;
        if (context.session) |session| {
            sessionFound = true;

            std.debug.assert(r.isFinished() == false);
            const message = std.fmt.bufPrint(&buf, "User: {s} / {any} Session token: {s}", .{
                session.user.name,
                session.user.pw_hash,
                session.token,
            }) catch unreachable;
            r.setContentType(.TEXT) catch unreachable;
            r.sendBody(message) catch unreachable;
            std.debug.assert(r.isFinished() == true);
            return true;
        }

        const message = std.fmt.bufPrint(&buf, "session info found: {}", .{ sessionFound }) catch unreachable;

        r.setContentType(.TEXT) catch unreachable;
        r.sendBody(message) catch unreachable;
        return true;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};

    // we start a block here so the defers will run before we call the gpa
    // to detect leaks
    {
        const allocator = gpa.allocator();
        SharedAllocator.init(allocator);

        try setup_routes(allocator);
        defer routes.deinit();

        state = try State.init(allocator);
        defer state.deinit();

        // we create our main middleware component that handles the request
        var apiHandler = try ApiMiddleWare.init(null);

        var sessionHandler = SessionMiddleWare.init(allocator, apiHandler.getHandler());

        var listener = try zap.Middleware.Listener(Context).init(
            .{
                .port = PORT,
                .on_request = null,
                .log = true,
                .max_clients = 100000,
                .public_folder = "src/ui",
            },
            sessionHandler.getHandler(),
            SharedAllocator.getAllocator,
        );
        try listener.listen();

        zap.enableDebugLog();

        std.debug.print("server live at http://127.0.0.1:{d}\n", .{PORT});

        // start worker threads
        zap.start(.{
            .threads = 2,
            .workers = 1,
        });
    }

    // all defers should have run by now
    std.debug.print("\n\nSTOPPED!\n", .{});
    const leaked = gpa.detectLeaks();
    std.debug.print("Leaks detected: {}\n", .{leaked});
}
