//! Helpers for working with timers and delay/sleeping.

const std = @import("std");

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
