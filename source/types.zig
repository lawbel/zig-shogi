//! This module contains the main datatypes we need for shogi, together with
//! some logic that is core to those types.
//!
//! Note on names: there is some variation in the english names used for some
//! pieces. The names we use here don't get shown to the user, so we've chosen
//! one set of names and will be sticking with that for consistency:
//!
//! * king (ōshō 王将 / gyokushō 玉将)
//! * rook (hisha 飛車)
//! * bishop (kakugyō 角行)
//! * gold (kinshō 金将)
//! * silver (ginshō 銀将)
//! * knight (keima 桂馬)
//! * lance (kyōsha 香車)
//! * pawn (fuhyō 歩兵)
//!
//! As well as these, we have the promoted pieces:
//!
//! * promoted rook (ryūō 竜王), also known as a dragon.
//! * promoted bishop (ryūma 竜馬), also known as a horse.
//! * promoted silver (narigin 成銀)
//! * promoted knight (narikei 成桂)
//! * promoted lance (narikyō 成香)
//! * promoted pawn (tokin と金), also known as a tokin.

const rules = @import("rules.zig");
const std = @import("std");
const tile_size = @import("render.zig").tile_size;

/// Our entire game state, which includes a mix of core types like `Board`
/// from `types.zig` and things relating to window/mouse state.
pub const State = struct {
    /// The state of the board.
    board: Board,
    /// Information needed for mouse interactions.
    mouse: struct {
        /// The current position of the mouse.
        pos: PixelPos,
        /// Whether there is a move currently being made with the mouse.
        move: struct {
            /// Where the move started - where left-click was first held down.
            from: ?PixelPos,
        },
    },
    /// The last move on the board (if any).
    last: ?struct {
        pos: BoardPos,
        move: Move,
    },
    /// Which colour is the player? The other will be the CPU.
    player: Player,
};

/// A vector `(x, y)` representing a move on our board. This could be simply
/// repositioning a piece, or it could be capturing another piece.
pub const Move = struct {
    x: i8,
    y: i8,

    /// Flip this move about the horizontal, effectively swapping the player
    /// it is for.
    pub fn flipHoriz(this: *@This()) void {
        this.y *= -1;
    }

    /// Is this move valid, considering the state of the `Board` for this
    /// player and the source position on the board.
    pub fn isValid(this: @This(), pos: BoardPos, board: Board) bool {
        const valid = rules.validMoves(pos, board);

        for (valid.slice()) |move| {
            if (move.x == this.x and move.y == this.y) {
                return true;
            }
        }

        return false;
    }
};

/// A position (x, y) in our game window. We use `i32` as the type, instead
/// of an alternative like `u16`, for ease when interfacing with the SDL
/// library.
pub const PixelPos = struct {
    x: i32,
    y: i32,

    /// Returns the position on the board at this location on the screen.
    pub fn toBoardPos(this: @This()) BoardPos {
        return .{
            .x = @intCast(@divFloor(this.x, tile_size)),
            .y = @intCast(@divFloor(this.y, tile_size)),
        };
    }

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

/// A position (x, y) on our board.
pub const BoardPos = struct {
    x: i8,
    y: i8,

    /// Check whether this position is actually valid for indexing into the
    /// `Board`.
    pub fn isInBounds(this: @This()) bool {
        const x_in_bounds = 0 <= this.x and this.x < Board.size;
        const y_in_bounds = 0 <= this.y and this.y < Board.size;
        return (x_in_bounds and y_in_bounds);
    }

    /// Apply a move to shift the given `ty.BoardPos`, returning the
    /// resulting position (or `null` if it would be out-of-bounds).
    pub fn makeMove(this: @This(), move: Move) ?@This() {
        const target: @This() = .{
            .x = this.x + move.x,
            .y = this.y + move.y,
        };
        return if (target.isInBounds()) target else null;
    }
};

/// An RGB colour, including an alpha (opacity) field.
pub const Colour = struct {
    red: u8 = 0,
    green: u8 = 0,
    blue: u8 = 0,
    alpha: u8 = @"opaque",

    pub const @"opaque" = std.math.maxInt(u8);
};

/// The possible players of the game.
pub const Player = union(enum) {
    /// Typically called white in English; gōte (後手) in Japanese. Goes second.
    white,
    /// Typically called black in English; sente (先手) in Japanese. Goes first.
    black,
};

/// A shogi piece. Includes promoted and non-promoted pieces.
pub const Piece = enum {
    /// The king (ōshō 王将 / gyokushō 玉将).
    king,

    /// A rook (hisha 飛車); can be promoted.
    rook,
    /// A promoted rook (ryūō 竜王).
    promoted_rook,

    /// A bishop (kakugyō 角行); can be promoted.
    bishop,
    /// A promoted bishop (ryūma 竜馬).
    promoted_bishop,

    /// A gold general (kinshō 金将).
    gold,

    /// A silver general (ginshō 銀将); can be promoted.
    silver,
    /// A promoted silver (narigin 成銀). Moves and attacks like a gold.
    promoted_silver,

    /// A knight (keima 桂馬); can be promoted.
    knight,
    /// A promoted knight (narikei 成桂). Moves and attacks like a gold.
    promoted_knight,

    /// A lance (kyōsha 香車); can be promoted.
    lance,
    /// A promoted lance (narikyō 成香). Moves and attacks like a gold.
    promoted_lance,

    /// A pawn (fuhyō 歩兵); can be promoted.
    pawn,
    /// A promoted pawn (tokin と金). Moves and attacks like a gold.
    promoted_pawn,

    /// Promote this piece. If it is already promoted or cannot be promoted,
    /// returns it as-is.
    pub fn promote(this: @This()) @This() {
        return switch (this) {
            .rook => .promoted_rook,
            .bishop => .promoted_bishop,
            .silver => .promoted_silver,
            .knight => .promoted_knight,
            .lance => .promoted_lance,
            .pawn => .promoted_pawn,
            else => this,
        };
    }

    /// Demote this piece. If it is already demoted or cannot be demoted,
    /// returns it as-is.
    pub fn demote(this: @This()) @This() {
        return switch (this) {
            .promoted_rook => .rook,
            .promoted_bishop => .bishop,
            .promoted_silver => .silver,
            .promoted_knight => .knight,
            .promoted_lance => .lance,
            .promoted_pawn => .pawn,
            else => this,
        };
    }
};

/// This type combines a `Piece` and a `Player` in one type.
pub const PlayerPiece = struct {
    player: Player,
    piece: Piece,

    /// The starting back row for a given player.
    pub fn backRow(player: Player) [Board.size]?@This() {
        return .{
            .{ .player = player, .piece = .lance },
            .{ .player = player, .piece = .knight },
            .{ .player = player, .piece = .silver },
            .{ .player = player, .piece = .gold },
            .{ .player = player, .piece = .king },
            .{ .player = player, .piece = .gold },
            .{ .player = player, .piece = .silver },
            .{ .player = player, .piece = .knight },
            .{ .player = player, .piece = .lance },
        };
    }

    /// The starting middle row for a given player.
    pub fn middleRow(player: Player) [Board.size]?@This() {
        const one = .{
            .player = player,
            .piece = switch (player) {
                .white => .rook,
                .black => .bishop,
            },
        };
        const two = .{
            .player = player,
            .piece = switch (player) {
                .white => .bishop,
                .black => .rook,
            },
        };

        return .{ null, one, null, null, null, null, null, two, null };
    }

    /// The starting front row for a given player.
    pub fn frontRow(player: Player) [Board.size]?@This() {
        return .{
            .{
                .player = player,
                .piece = .pawn,
            },
        } ** Board.size;
    }
};

const empty_hand: std.EnumMap(Piece, i8) = init: {
    var map: std.EnumMap(Piece, i8) = .{};

    for (@typeInfo(Piece).Enum.fields) |field| {
        map.put(@enumFromInt(field.value), 0);
    }

    break :init map;
};

/// This type represents the pure state of the board, and has some associated
/// functionality.
pub const Board = struct {
    /// Which (if any) piece (a `PlayerPiece`) is on each square/tile.
    tiles: [size][size]?PlayerPiece,

    /// Which pieces does each player have in hand?
    hand: struct {
        /// What pieces does white have in hand, and how many of each?
        white: std.EnumMap(Piece, i8),
        /// What pieces does black have in hand, and how many of each?
        black: std.EnumMap(Piece, i8),
    },

    /// The size of the board (i.e. its width/height).
    pub const size = 9;

    /// The initial / starting state of the board.
    pub const init: @This() = .{
        .tiles = .{
            // White's territory.
            PlayerPiece.backRow(.white),
            PlayerPiece.middleRow(.white),
            PlayerPiece.frontRow(.white),

            // No-mans land.
            .{null} ** size,
            .{null} ** size,
            .{null} ** size,

            // Black's territory.
            PlayerPiece.frontRow(.black),
            PlayerPiece.middleRow(.black),
            PlayerPiece.backRow(.black),
        },

        .hand = .{
            .white = empty_hand,
            .black = empty_hand,
        },
    };

    /// Get the `PlayerPiece` (if any) at the given position.
    pub fn get(this: @This(), pos: BoardPos) ?PlayerPiece {
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        return this.tiles[y][x];
    }

    /// Set (or delete) the piece present at the given position.
    pub fn set(this: *@This(), pos: BoardPos, piece: ?PlayerPiece) void {
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        this.tiles[y][x] = piece;
    }
};
