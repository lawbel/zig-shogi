//! Helpers for working with randomness.

const std = @import("std");

/// Any error that can occur when working with these randomization functions.
pub const RandomError = error{
    RandomGetFromOs,
};

/// Get a random `u64` from the operating system.
pub fn randomSeedFromOs() RandomError!u64 {
    var buffer: [8]u8 = undefined;
    var seed_u64: u64 = 0;

    // This can throw a number of different errors; for now we combine them
    // into one.
    std.os.getrandom(&buffer) catch return error.RandomGetFromOs;

    inline for (0..buffer.len) |i| {
        const IntType = @TypeOf(buffer[0]);
        const bit_size = @typeInfo(IntType).Int.bits;
        const value: u64 = @intCast(buffer[i]);
        const mask: u64 = value << (bit_size * i);
        seed_u64 |= mask;
    }

    return seed_u64;
}
