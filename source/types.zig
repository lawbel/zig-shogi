const std = @import("std");

pub const Colour = struct {
    red: u8,
    green: u8,
    blue: u8,
    alpha: u8 = @"opaque",

    pub const @"opaque" = std.math.maxInt(u8);
};

pub const IsPromoted =
    union(enum) { basic, promoted };

pub const Player =
    union(enum) { white, black };

pub const Kind = enum {
    king,
    rook,
    bishop,
    gold,
    silver,
    knight,
    lance,
    pawn,

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

pub const Piece = union(Kind) {
    king,
    rook: IsPromoted,
    bishop: IsPromoted,
    gold,
    silver: IsPromoted,
    knight: IsPromoted,
    lance: IsPromoted,
    pawn: IsPromoted,
};

pub const PlayerPiece = struct {
    player: Player,
    piece: Piece,

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

    pub fn frontRow(player: Player) [Board.size]?@This() {
        return .{
            .{
                .player = player,
                .piece = .{ .pawn = .basic },
            },
        } ** Board.size;
    }
};

pub const Board = struct {
    squares: [size][size]?PlayerPiece,
    white_hand: std.EnumMap(Kind, i8),
    black_hand: std.EnumMap(Kind, i8),

    pub const size = 9;

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
