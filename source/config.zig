//! This module acts as a central location for various constants that are
//! needed in multiple places, or feel at home grouped together with such.
//!
//! This also acts as a kind of one-stop-shop for making simple adjustments to
//! how the program runs.

const c = @import("c.zig");
const ty = @import("types.zig");

pub const window_title: [:0]const u8 = "Zig Shogi";

pub const tile_size: c_int = 70;
pub const window_width: c_int = tile_size * ty.Board.size;
pub const window_height: c_int = tile_size * ty.Board.size;

pub const window_flags: u32 = 0;

pub const sdl_init_flags: u32 =
    c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS;

pub const fps: u32 = 60;
