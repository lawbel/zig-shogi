//! This module contains functionality and definitions to do with pixel
//! positions on the screen, and pixel colour values.

const model = @import("model.zig");
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

    /// Returns the position on the board at this location on the screen.
    pub fn toBoardPos(this: @This()) model.BoardPos {
        return .{
            .x = @intCast(@divFloor(this.x, tile_size)),
            .y = @intCast(@divFloor(this.y, tile_size)),
        };
    }

    /// Whether or not these coordinates are within the bounds of the board.
    pub fn isOnTheBoard(this: @This()) bool {
        const board_size_pix = tile_size * model.Board.size;

        const x_on_board =
            board_top_left.x <= this.x and
            this.x < board_top_left.x + board_size_pix;
        const y_on_board =
            board_top_left.y <= this.y and
            this.y < board_top_left.y + board_size_pix;

        return x_on_board and y_on_board;
    }
};

/// The coordinates of the top-left corner of the board.
pub const board_top_left: PixelPos = .{
    .x = 175,
    .y = 35,
};

test "PixelPos.toBoardPos(n*size, n*size) returns (n, n)" {
    for (0..model.Board.size) |n| {
        const n_float: f32 = @floatFromInt(n);
        const tile_size_float: f32 = @floatFromInt(tile_size);

        // A pixel dead-centre in the middle of the intended tile.
        const pix: PixelPos = .{
            .x = @intFromFloat((n_float + 0.5) * tile_size_float),
            .y = @intFromFloat((n_float + 0.5) * tile_size_float),
        };
        const pos: model.BoardPos = .{
            .x = @intCast(n),
            .y = @intCast(n),
        };

        try std.testing.expectEqual(pix.toBoardPos(), pos);
    }
}
