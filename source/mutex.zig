//! This module implements functionality for working with concurrency.

const std = @import("std");

/// Represents a value guarded behind a `std.Thread.Mutex`. The contained value
/// is always an optional of the given type.
pub fn MutexGuard(comptime T: type) type {
    return struct {
        mutex: std.Thread.Mutex,
        data: ?T,

        /// Initialize a new `MutexGuard` taking an optional initial value.
        pub fn init(value: ?T) @This() {
            return .{
                .mutex = .{},
                .data = value,
            };
        }

        /// Set the contained value. This call will block until the lock can
        /// be obtained.
        pub fn setValue(this: *@This(), value: ?T) void {
            this.mutex.lock();
            defer this.mutex.unlock();

            this.data = value;
        }

        /// Get the contained value. This call will block until the lock can
        /// be obtained.
        pub fn getValue(this: *@This()) ?T {
            this.mutex.lock();
            defer this.mutex.unlock();

            return this.data;
        }

        /// Get the contained value (if any), replacing it with `null`. This
        /// call will block until the lock can be obtained.
        pub fn takeValue(this: *@This()) ?T {
            this.mutex.lock();
            defer this.mutex.unlock();

            const value = this.data;
            this.data = null;
            return value;
        }
    };
}
