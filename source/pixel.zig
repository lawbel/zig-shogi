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
pub const tile_size: i16 = 70;

/// A position (x, y) in our game window.
pub const PixelPos = struct {
    x: i16,
    y: i16,

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
    pub fn offsetFromBoard(this: @This()) @This() {
        const from_top_left = this.subtract(board_top_left);
        return .{
            .x = @mod(from_top_left.x, tile_size),
            .y = @mod(from_top_left.y, tile_size),
        };
    }

    /// Returns the position on the board at this location on the screen.
    pub fn toBoardPos(this: @This()) ?model.BoardPos {
        if (!this.onTheBoard()) return null;

        const from_top_left = this.subtract(board_top_left);
        return .{
            .x = @intCast(@divFloor(from_top_left.x, tile_size)),
            .y = @intCast(@divFloor(from_top_left.y, tile_size)),
        };
    }

    /// Whether or not these coordinates are within the bounds of the board.
    pub fn onTheBoard(this: @This()) bool {
        const x_on_board =
            board_top_left.x <= this.x and
            this.x < board_top_left.x + board_size_pix;
        const y_on_board =
            board_top_left.y <= this.y and
            this.y < board_top_left.y + board_size_pix;

        return x_on_board and y_on_board;
    }

    /// Returns the piece (if any) at the given position in either
    /// player's hand.
    pub fn toHandPiece(this: @This()) ?model.Piece {
        const player = this.inPlayersHand() orelse return null;

        const top_y = switch (player) {
            .white => left_hand_top_left.y,
            .black => right_hand_top_left.y,
        };
        const index: usize = @intCast(@divFloor(this.y - top_y, tile_size));
        const sort = order_of_pieces_in_hand[index];

        return .{ .sort = sort, .player = player };
    }

    /// Whether or not these coordinates are within the bounds of the hand box
    /// for one of the players, and if so, which player.
    pub fn inPlayersHand(this: @This()) ?model.Player {
        if (this.inWhiteHand()) return .white;
        if (this.inBlackHand()) return .black;
        return null;
    }

    /// Whether the position is within the white player's hand.
    ///
    /// TODO: Remove the assumption here, and elsewhere, that the user is
    /// playing as black.
    fn inWhiteHand(this: @This()) bool {
        return this.inHandAt(left_hand_top_left);
    }

    /// Whether the position is within the white player's hand.
    fn inBlackHand(this: @This()) bool {
        return this.inHandAt(right_hand_top_left);
    }

    /// Whether the position is within the given hand.
    fn inHandAt(this: @This(), hand_top_left: @This()) bool {
        const x_in_hand =
            hand_top_left.x <= this.x and
            this.x < hand_top_left.x + tile_size;

        const height: i16 = tile_size * order_of_pieces_in_hand.len;
        const y_in_hand =
            hand_top_left.y <= this.y and
            this.y < hand_top_left.y + height;

        return x_in_hand and y_in_hand;
    }

    /// Returns the offset of this position from the grid in the users' hand.
    pub fn offsetFromUserHand(this: @This()) @This() {
        const from_top_left = this.subtract(right_hand_top_left);
        return .{
            .x = @mod(from_top_left.x, tile_size),
            .y = @mod(from_top_left.y, tile_size),
        };
    }
};

/// The order of promotion choices - that is, when displaying on-screen a
/// collection of possible promoted pieces to choose from, what order should
/// we show them in. So `true` represents a promoted piece, while `false`
/// represents a base un-promoted piece.
pub const order_of_promotion_choices: [2]bool = .{ true, false };

/// The board positions where the promotion overlay should be displayed.
pub fn promotionOverlayAt(pos: model.BoardPos) [2]model.BoardPos {
    const n = 2;
    var ys = [n]i8{ pos.y, pos.y + 1 };

    // Need to take care not to fall off the edge of the board. So we check if
    // the last position would be out of bounds, and in that case move
    // everything up by one.
    if (ys[n - 1] >= model.Board.size) {
        for (&ys) |*y| {
            y.* -= 1;
        }
    }

    return [n]model.BoardPos{
        .{ .x = pos.x, .y = ys[0] },
        .{ .x = pos.x, .y = ys[1] },
    };
}

/// The coordinates of the top-left corner of the board.
pub const board_top_left: PixelPos = .{
    .x = 175,
    .y = 35,
};

/// The coordinates of the top-left corner of the hand shown on the left.
pub const left_hand_top_left: PixelPos = .{
    .x = 35,
    .y = 35,
};

/// The coordinates of the top-left corner of the hand shown on the right.
pub const right_hand_top_left: PixelPos = init: {
    var x = 0;

    x += board_top_left.x;
    x += tile_size * model.Board.size;
    x += board_top_left.x - left_hand_top_left.x - tile_size;

    break :init .{ .x = x, .y = 175 };
};

/// How much bigger the window should be horizontally, compared to the
/// board size.
pub const board_padding_horiz: i16 = board_top_left.x * 2;

/// How much bigger the window should be vertically, compared to the
/// board size.
pub const board_padding_vert: i16 = board_top_left.y * 2;

/// The size of the board (width/height), in pixels.
const board_size_pix: i16 = tile_size * model.Board.size;

/// The order (top-to-bottom) of the pieces in-hand. This determines how we
/// will draw the player hands, and is also needed to properly implement the
/// ability of the user to drop pieces on the board.
pub const order_of_pieces_in_hand = [7]model.Sort{
    .rook,
    .bishop,
    .gold,
    .silver,
    .knight,
    .lance,
    .pawn,
};

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
