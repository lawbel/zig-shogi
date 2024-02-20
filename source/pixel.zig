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

    /// Add these coordinates together.
    pub fn add(this: @This(), other: @This()) @This() {
        return .{
            .x = this.x + other.x,
            .y = this.y + other.y,
        };
    }

    /// Subtract the second coordinate from the
    /// first: `a.subtract(b) == a - b`.
    pub fn subtract(this: @This(), other: @This()) @This() {
        return .{
            .x = this.x - other.x,
            .y = this.y - other.y,
        };
    }

    /// Returns the offset of this position from the board grid. For example,
    /// if this position is right in the middle of a tile, it would return
    /// `(tile_size / 2, tile_size / 2)`.
    pub fn offsetFromGrid(this: @This()) @This() {
        const from_top_left = this.subtract(board_top_left);
        return .{
            .x = @mod(from_top_left.x, tile_size),
            .y = @mod(from_top_left.y, tile_size),
        };
    }

    /// Returns the position on the board at this location on the screen.
    pub fn toBoardPos(this: @This()) ?model.BoardPos {
        if (!this.isOnTheBoard()) return null;

        const from_top_left = this.subtract(board_top_left);
        return .{
            .x = @intCast(@divFloor(from_top_left.x, tile_size)),
            .y = @intCast(@divFloor(from_top_left.y, tile_size)),
        };
    }

    /// Whether or not these coordinates are within the bounds of the board.
    pub fn isOnTheBoard(this: @This()) bool {
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

/// How much bigger the window should be horizontally, compared to the
/// board size.
pub const board_padding_horiz: i32 = board_top_left.x * 2;

/// How much bigger the window should be vertically, compared to the
/// board size.
pub const board_padding_vert: i32 = board_top_left.y * 2;

/// The size of the board (width/height), in pixels.
const board_size_pix: c_int = tile_size * model.Board.size;

test "PixelPos.toBoardPos(n*size, n*size) returns (n, n)" {
    for (0..model.Board.size) |n| {
        const n_float: f32 = @floatFromInt(n);
        const tile_size_float: f32 = @floatFromInt(tile_size);

        // A pixel dead-centre in the middle of the intended tile.
        const base_pix: PixelPos = .{
            .x = @intFromFloat((n_float + 0.5) * tile_size_float),
            .y = @intFromFloat((n_float + 0.5) * tile_size_float),
        };
        const pix = base_pix.add(board_top_left);

        const pos: model.BoardPos = .{
            .x = @intCast(n),
            .y = @intCast(n),
        };

        try std.testing.expectEqual(pix.toBoardPos(), pos);
    }
}
