const std = @import("std");
const zap = @import("zap");
const State = @import("state.zig");
const WebSockets = zap.WebSockets;

const ChannelList = std.ArrayList(*Channel);
pub const Handler = WebSockets.Handler(Channel);

const Channel = struct {
    state: *State,
    userName: []const u8,
    channel: []const u8,
    manager: *ChannelManager,
    // we need to hold on to them and just re-use them for every incoming
    // connection
    subscribeArgs: Handler.SubscribeArgs,
    settings: Handler.WebSocketSettings,
};

pub const ChannelManager = struct {
    allocator: std.mem.Allocator,
    channel: []const u8,
    channelname_prefix: []const u8,
    lock: std.Thread.Mutex = .{},
    channels: ChannelList = undefined,
    state: *State,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        channelName: []const u8,
        channelname_prefix: []const u8,
        state: *State,
    ) Self {
        return .{
            .allocator = allocator,
            .channel = channelName,
            .channelname_prefix = channelname_prefix,
            .channels = ChannelList.init(allocator),
            .state = state,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.channels.items) |chan| {
            std.log.err("closing channel ptr: {*}", .{chan});
            self.allocator.free(chan.userName);
            self.allocator.destroy(chan);
        }
        self.channels.deinit();
    }

    pub fn newChannel(self: *Self) !*Channel {
        self.lock.lock();
        defer self.lock.unlock();

        const chan = try self.allocator.create(Channel);
        std.log.err("channel ptr: {*}", .{chan});
        const userName = try std.fmt.allocPrint(
            self.allocator,
            "{s}{d}",
            .{ self.channelname_prefix, self.channels.items.len },
        );
        chan.* = .{
            .state = self.state,
            .userName = userName,
            .channel = self.channel,
            .manager = self,
            // used in subscribe()
            .subscribeArgs = .{
                .channel = self.channel,
                .force_text = true,
                .context = chan,
            },
            // used in upgrade()
            .settings = .{
                .on_open = onOpenWebsocket,
                .on_close = on_close_websocket,
                .on_message = handle_websocket_message,
                .context = chan,
            },
        };
        try self.channels.append(chan);
        return chan;
    }
};

//
// Websocket Callbacks
//
fn onOpenWebsocket(channel: ?*Channel, handle: WebSockets.WsHandle) void {
    if (channel) |chan| {
        _ = Handler.subscribe(handle, &chan.subscribeArgs) catch |err| {
            std.log.err("Error opening websocket: {any}", .{err});
            return;
        };

        // dump current state
        var buf: [1024 * 64]u8 = undefined;
        const message = chan.state.writeJson(&buf);

        // send notification to all others
        Handler.publish(.{ .channel = chan.channel, .message = message });
    }
}

fn on_close_websocket(channel: ?*Channel, uuid: isize) void {
    _ = uuid;
    if (channel) |chan| {
        for (chan.manager.channels.items, 0..) |*ptr, i| {
            if (ptr == &chan) {
                std.log.err("closing channel ptr: {*}", .{&chan});
                chan.manager.allocator.free(chan.userName);
                chan.manager.allocator.destroy(chan.manager.channels.orderedRemove(i));
                break;
            }
        }
    //    // say goodbye
    //    var buf: [128]u8 = undefined;
    //    const message = std.fmt.bufPrint(
    //        &buf,
    //        "{s} left the chat.",
    //        .{chan.userName},
    //    ) catch unreachable;

    //    // send notification to all others
    //    Handler.publish(.{ .channel = chan.channel, .message = message });
    //    std.log.info("websocket closed: {s}", .{message});
    }
}

fn handle_websocket_message(
    channel: ?*Channel,
    handle: WebSockets.WsHandle,
    message: []const u8,
    is_text: bool,
) void {
    _ = is_text;
    _ = handle;
    if (channel) |chan| {
        // send message
        const buflen = 128; // arbitrary len
        var buf: [buflen]u8 = undefined;

        const format_string = "{s}: {s}";
        const fmt_string_extra_len = 2; // ": " between the two strings
        //
        const max_msg_len = buflen - chan.userName.len - fmt_string_extra_len;
        if (max_msg_len > 0) {
            // there is space for the message, because the user name + format
            // string extra do not exceed the buffer now, let's check: do we
            // need to trim the message?
            var trimmed_message: []const u8 = message;
            if (message.len > max_msg_len) {
                trimmed_message = message[0..max_msg_len];
            }
            const chat_message = std.fmt.bufPrint(
                &buf,
                format_string,
                .{ chan.userName, trimmed_message },
            ) catch unreachable;

            // send notification to all others
            Handler.publish(
                .{ .channel = chan.channel, .message = chat_message },
            );
            std.log.info("{s}", .{chat_message});
        } else {
            std.log.warn(
                "Username is very long, cannot deal with that size: {d}",
                .{chan.userName.len},
            );
        }
    }
}

