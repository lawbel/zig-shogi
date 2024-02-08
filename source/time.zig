//! Helpers for working with timers and delay/sleeping.

const c = @import("c.zig");
const std = @import("std");

/// Target frames per second.
const fps: u32 = 60;

/// Implements a 'stopwatch' - it can be started, and the current time can be
/// read off. Tries to use `std.time.Timer`; if that isn't supported, falls
/// back to using `std.time.microTimestamp`.
pub const Stopwatch = union(enum) {
    timer: std.time.Timer,
    init: i64,

    pub fn start() @This() {
        if (std.time.Timer.start()) |timer| {
            return .{ .timer = timer };
        } else |_| {
            return .{ .init = std.time.microTimestamp() };
        }
    }

    pub fn read(this: *@This()) u64 {
        switch (this.*) {
            .timer => |*timer| return timer.read(),
            .init => |init| {
                const now = std.time.microTimestamp();
                return @intCast(now - init);
            },
        }
    }
};

/// Call the given function with the given arguments, taking at-least the given
/// time in seconds.
pub fn callTakeAtLeast(
    min_duration_s: f32,
    comptime function: anytype,
    args: anytype,
) @TypeOf(@call(.auto, function, args)) {
    var timer = Stopwatch.start();

    const begin = timer.read();
    const result = @call(.auto, function, args);
    const end = timer.read();

    const time_taken_ns: u64 = end - begin;
    const min_duration_ns: u64 =
        @intFromFloat(min_duration_s * std.time.ns_per_s);

    if (time_taken_ns < min_duration_ns) {
        std.time.sleep(min_duration_ns - time_taken_ns);
    }

    return result;
}

/// If we used less time than needed to hit our target `fps`, then delay
/// for the left-over time before starting on the next frame.
pub fn sleepToMatchFps(last_frame: *u32) void {
    // The target duration of one frame, in milliseconds.
    const one_frame: u32 = 1000 / fps;

    // for the left-over time before starting on the next frame.
    const this_frame = c.SDL_GetTicks();
    const time_spent = this_frame - last_frame.*;

    if (time_spent < one_frame) {
        c.SDL_Delay(one_frame - time_spent);
    }

    last_frame.* = this_frame;
}
