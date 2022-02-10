const std = @import("std");
const uv = @import("uv");
const builtin = @import("builtin");

const log = std.log.scoped(.uv_poller);
const mac_sys = @import("mac_sys.zig");

/// A dedicated thread is used to poll libuv's backend fd.
pub const UvPoller = struct {
    const Self = @This();

    uv_loop: *uv.uv_loop_t,
    inner: switch (builtin.os.tag) {
        .linux => UvPollerLinux,
        .macos => UvPollerMac,
        .windows => UvPollerWindows,
        else => unreachable,
    },

    // Must refer to the same address in memory.
    notify: *std.Thread.ResetEvent,

    close_flag: std.atomic.Atomic(bool),

    pub fn init(uv_loop: *uv.uv_loop_t, notify: *std.Thread.ResetEvent) Self {
        var new = Self{
            .uv_loop = uv_loop,
            .inner = undefined,
            .notify = notify,
            .close_flag = std.atomic.Atomic(bool).init(false),
        };
        new.inner.init(uv_loop);
        return new;
    }

    pub fn run(self: *Self) void {
        while (true) {
            if (self.close_flag.load(.Acquire)) {
                break;
            }

            // log.debug("uv poller wait", .{});
            self.inner.poll(self.uv_loop);
            // log.debug("uv poller wait return {}", .{uv.uv_loop_alive(self.uv_loop)});

            // Notify that there is new uv work to process.
            self.notify.set();
        }

        // Reuse flag to indicate the thread is done.
        self.close_flag.store(false, .Release);
    }
};

const UvPollerLinux = struct {
    const Self = @This();

    epfd: i32,

    fn init(self: *Self, uv_loop: *uv.uv_loop_t) void {
        const backend_fd = uv.uv_backend_fd(uv_loop);

        var evt: std.os.linux.epoll_event = undefined;
        evt.events = std.os.linux.EPOLL.IN;
        evt.data.fd = backend_fd;

        const epfd = std.os.epoll_create1(std.os.linux.EPOLL.CLOEXEC) catch unreachable;
        std.os.epoll_ctl(epfd, std.os.linux.EPOLL.CTL_ADD, backend_fd, &evt) catch unreachable;

        self.* = .{
            .epfd = epfd,
        };
    }

    fn poll(self: Self, uv_loop: *uv.uv_loop_t) void {
        const timeout = uv.uv_backend_timeout(uv_loop);
        var evts: [1]std.os.linux.epoll_event = undefined;
        _ = std.os.epoll_wait(self.epfd, &evts, timeout);
    }
};

const UvPollerMac = struct {
    const Self = @This();

    fn init(self: *Self, uv_loop: *uv.uv_loop_t) void {
        _ = self;
        _ = uv_loop;
    }

    fn poll(self: Self, uv_loop: *uv.uv_loop_t) void {
        _ = self;
        var tv: mac_sys.timeval = undefined;
        const timeout = uv.uv_backend_timeout(uv_loop);
        if (timeout != -1) {
            tv.tv_sec = @divTrunc(timeout, 1000);
            tv.tv_usec = @rem(timeout, 1000) * 1000;
        }

        var readset: mac_sys.fd_set = undefined;
        const fd = uv.uv_backend_fd(uv_loop);
        mac_sys.sys_FD_ZERO(&readset);
        mac_sys.sys_FD_SET(fd, &readset);

        var r: c_int = undefined;
        while (true) {
            r = mac_sys.select(fd + 1, &readset, null, null, if (timeout == -1) null else &tv);
            if (r != -1 or std.os.errno(r) != .INTR) {
                break;
            }
        }
    }
};

const UvPollerWindows = struct {
    const Self = @This();

    fn init(self: *Self, uv_loop: *uv.uv_loop_t) void {
        _ = self;
        _ = uv_loop;
    }

    fn poll(self: Self, uv_loop: *uv.uv_loop_t) void {
        _ = self;

        var bytes: u32 = undefined;
        var key: usize = undefined;
        var overlapped: ?*std.os.windows.OVERLAPPED = null;

        // Wait forever if -1 is returned.
        const timeout = uv.uv_backend_timeout(uv_loop);
        if (timeout == -1) {
            // Call directly since zig's abstraction will panic on expected errors.
            _ = std.os.windows.kernel32.GetQueuedCompletionStatus(uv_loop.iocp.?, &bytes, &key, &overlapped, std.os.windows.INFINITE);
        } else {
            _ = std.os.windows.kernel32.GetQueuedCompletionStatus(uv_loop.iocp.?, &bytes, &key, &overlapped, @intCast(u32, timeout));
        }

        // Give the event back so libuv can deal with it.
        if (overlapped != null) {
            std.os.windows.PostQueuedCompletionStatus(uv_loop.iocp.?, bytes, key, overlapped) catch |err| {
                log.debug("PostQueuedCompletionStatus error: {}", .{err});
            }; 
        }
    }
};

