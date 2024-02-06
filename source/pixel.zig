//! This module contains functionality and definitions to do with pixel
//! positions on the screen, and pixel colour values.

const std = @import("std");

/// An RGB colour, including an alpha (opacity) field.
pub const Colour = struct {
    red: u8 = 0,
    green: u8 = 0,
    blue: u8 = 0,
    alpha: u8 = max_opacity,

    pub const max_opacity = std.math.maxInt(u8);
};

/// The size (in pixels) of one tile/square on the game board.
pub const tile_size: c_int = 70;

/// A position (x, y) in our game window. We use `i32` as the type, instead
/// of an alternative like `u16`, for ease when interfacing with the SDL
/// library.
pub const PixelPos = struct {
    x: i32,
    y: i32,

    /// Returns the offset of this position from the board grid. For example,
    /// if this position is right in the middle of a tile, it would return
    /// `(tile_size / 2, tile_size / 2)`.
    pub fn offsetFromGrid(this: @This()) @This() {
        return .{
            .x = @mod(this.x, tile_size),
            .y = @mod(this.y, tile_size),
        };
    }
};
