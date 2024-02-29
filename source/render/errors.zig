//! Contains common error types used while rendering.

const sdl = @import("../sdl.zig");
const std = @import("std");

/// Any kind of error that can occur during rendering.
pub const Error = sdl.Error || std.mem.Allocator.Error;
