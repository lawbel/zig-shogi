//! This module acts as a central location for various constants that are
//! needed in multiple places, or feel at home grouped together with such.
//!
//! This also acts as a kind of one-stop-shop for making simple adjustments to
//! how the program runs.

const c = @import("c.zig");
const ty = @import("types.zig");

/// The size (in pixels) of one tile/square on the game board.
pub const tile_size: c_int = 70;

/// Desired frames per second.
pub const fps: u32 = 60;
