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
    /// Which colour is the player? The other will be the CPU.
    player: Player,
};

/// A position (x, y) in our game window. We use `i32` as the type, instead
/// of an alternative like `u16`, for ease when interfacing with the SDL
/// library.
pub const PixelPos = struct {
    x: i32,
    y: i32,

    pub fn toBoardPos(this: @This()) BoardPos {
        return .{
            .x = @intCast(@divFloor(this.x, tile_size)),
            .y = @intCast(@divFloor(this.y, tile_size)),
        };
    }

    pub fn offsetFromGrid(this: @This()) @This() {
        return .{
            .x = @mod(this.x, tile_size),
            .y = @mod(this.y, tile_size),
        };
    }
};

/// A position (x, y) on our board.
pub const BoardPos =
    struct { x: i8, y: i8 };

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
            .white = .{},
            .black = .{},
        },
    };
};
