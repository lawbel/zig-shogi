//! This module contains the main datatypes we need for shogi, together with
//! some logic that is core to those types.
//!
//! Note on names: there is some variation in the english names used for some
//! pieces. The names we use here don't get shown to the user, so we've chosen
//! one set of names and will be sticking with that for consistency:
//!
//! * king (ōshō 王将 / gyokushō 玉将)
//! * rook (hisha 飛車)
//! * dragon (ryūō 竜王)
//! * bishop (kakugyō 角行)
//! * horse (ryūma 竜馬)
//! * gold (kinshō 金将)
//! * silver (ginshō 銀将)
//! * knight (keima 桂馬)
//! * lance (kyōsha 香車)
//! * pawn (fuhyō 歩兵)

const std = @import("std");

/// An RGB colour, including an alpha (opacity) field.
pub const Colour = struct {
    red: u8,
    green: u8,
    blue: u8,
    alpha: u8 = @"opaque",

    pub const @"opaque" = std.math.maxInt(u8);
};

/// Whether a piece is promoted or not.
pub const IsPromoted = union(enum) {
    /// This piece is not promoted.
    basic,
    /// This piece *is* promoted.
    promoted,
};

/// The possible players of the game.
pub const Player = union(enum) {
    /// Typically called white in English; sente (先手) in Japanese.
    white,
    /// Typically called black in English; gōte (後手) in Japanese.
    black,
};

/// The 'kind' of a piece.
///
/// We don't include promoted pieces in this datatype, only the 'base' type
/// of the piece. You can think of it that this type represents every possible
/// 'face-up' piece. For more detailed documentation on each piece, see the
/// variants of `Piece`.
pub const Kind = enum {
    /// The king (ōshō 王将 / gyokushō 玉将).
    king,
    /// A rook (hisha 飛車).
    rook,
    /// A bishop (kakugyō 角行).
    bishop,
    /// A gold general (kinshō 金将).
    gold,
    /// A silver general (ginshō 銀将).
    silver,
    /// A knight (keima 桂馬).
    knight,
    /// A lance (kyōsha 香車).
    lance,
    /// A pawn (fuhyō 歩兵).
    pawn,

    /// The size of the piece on the board - though they are similarly-sized,
    /// the more important / powerful pieces are physically larger.
    pub fn size(this: @This()) u8 {
        return switch (this) {
            .king => 6,
            .rook, .bishop => 5,
            .gold, .silver => 4,
            .knight => 3,
            .lance => 2,
            .pawn => 1,
        };
    }
};

/// A piece, which is a combination of a `Kind` and (if relevant) `IsPromoted`.
///
/// Compared to `Kind`, you can think of this type as representing any possible
/// piece on the board, be it face-up or flipped/promoted.
pub const Piece = union(Kind) {
    /// The king (ōshō 王将 / gyokushō 玉将). We only have one variant here
    /// for the king for simplicity, even though the two kings could be
    /// considered to be different and should look different for both players.
    /// Cannot be promoted.
    king,
    /// In basic form, this is a rook (hisha 飛車). In promoted form, this
    /// becomes a dragon (ryūō 竜王).
    rook: IsPromoted,
    /// In basic form, this is a bishop (kakugyō 角行). When promoted, it
    /// becomes a horse (ryūma 竜馬).
    bishop: IsPromoted,
    /// A gold general (kinshō 金将). Cannot be promoted.
    gold,
    /// A silver general (ginshō 銀将). Promotes into a gold general (narigin
    /// 成銀). Note that the promoted form is visually distinct, it is
    /// different from a basic gold general or any other kind of piece promoted
    /// to a gold general.
    silver: IsPromoted,
    /// A knight (keima 桂馬). Promotes into a gold general (narikei 成桂). Note
    /// that the promoted form is visually distinct, it is different from a
    /// basic gold general or any other kind of piece promoted to a gold
    /// general.
    knight: IsPromoted,
    /// A lance (kyōsha 香車). Promotes into a gold general (narikyō 成香). Note
    /// that the promoted form is visually distinct, it is different from a
    /// basic gold general or any other kind of piece promoted to a gold
    /// general.
    lance: IsPromoted,
    /// A pawn (fuhyō 歩兵). Promotes into a gold general (tokin と金). Note
    /// that the promoted form should be visually distinct, it is different
    /// from a basic gold general or any other kind of piece promoted to a
    /// gold general.
    pawn: IsPromoted,
};

/// This type combines a `Piece` and a `Player` in one type.
pub const PlayerPiece = struct {
    player: Player,
    piece: Piece,

    /// The starting back row for a given player.
    pub fn backRow(player: Player) [Board.size]?@This() {
        return .{
            .{ .player = player, .piece = .{ .lance = .basic } },
            .{ .player = player, .piece = .{ .knight = .basic } },
            .{ .player = player, .piece = .{ .silver = .basic } },
            .{ .player = player, .piece = .gold },
            .{ .player = player, .piece = .king },
            .{ .player = player, .piece = .gold },
            .{ .player = player, .piece = .{ .silver = .basic } },
            .{ .player = player, .piece = .{ .knight = .basic } },
            .{ .player = player, .piece = .{ .lance = .basic } },
        };
    }

    /// The starting middle row for a given player.
    pub fn middleRow(player: Player) [Board.size]?@This() {
        const one = .{
            .player = player,
            .piece = switch (player) {
                .white => .{ .bishop = .basic },
                .black => .{ .rook = .basic },
            },
        };
        const two = .{
            .player = player,
            .piece = switch (player) {
                .white => .{ .rook = .basic },
                .black => .{ .bishop = .basic },
            },
        };

        return .{ null, one, null, null, null, null, null, two, null };
    }

    /// The starting front row for a given player.
    pub fn frontRow(player: Player) [Board.size]?@This() {
        return .{
            .{
                .player = player,
                .piece = .{ .pawn = .basic },
            },
        } ** Board.size;
    }
};

/// This type represents the pure state of the board, and has some associated
/// functionality.
pub const Board = struct {
    /// Which (if any) piece (a `PlayerPiece`) is on each square.
    squares: [size][size]?PlayerPiece,
    /// What pieces does white have in hand, how many of each `Kind`?
    white_hand: std.EnumMap(Kind, i8),
    /// What pieces does black have in hand, how many of each `Kind`?
    black_hand: std.EnumMap(Kind, i8),

    /// The size of the board (i.e. its width/height).
    pub const size = 9;

    /// The initial / starting state of the board.
    pub const init: @This() = .{
        .squares = .{
            // Black's territory.
            PlayerPiece.backRow(.black),
            PlayerPiece.middleRow(.black),
            PlayerPiece.frontRow(.black),

            // No-mans land.
            .{null} ** size,
            .{null} ** size,
            .{null} ** size,

            // White's territory.
            PlayerPiece.frontRow(.white),
            PlayerPiece.middleRow(.white),
            PlayerPiece.backRow(.white),
        },

        .white_hand = .{},
        .black_hand = .{},
    };
};
