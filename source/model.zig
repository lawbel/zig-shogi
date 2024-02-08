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

const pixel = @import("pixel.zig");
const std = @import("std");

/// A choice of move to make on the board. Used for the CPU player.
/// TODO: handle drops.
pub const Move = struct {
    pos: BoardPos,
    motion: Motion,
};

/// A vector `(x, y)` representing a motion on our board. This could be simply
/// repositioning a piece, or it could be capturing another piece.
pub const Motion = struct {
    x: i8,
    y: i8,

    /// Flip this motion about the horizontal, effectively swapping the player
    /// it is for.
    pub fn flipHoriz(this: *@This()) void {
        this.y *= -1;
    }
};

test "Motion.flipHoriz flips y" {
    var move: Motion = .{ .x = 1, .y = 2 };
    move.flipHoriz();
    const result: Motion = .{ .x = 1, .y = -2 };
    try std.testing.expectEqual(move, result);
}

test "Motion.flipHoriz does nothing when y = 0" {
    const before: Motion = .{ .x = -5, .y = 0 };
    var after = before;
    after.flipHoriz();
    try std.testing.expectEqual(before, after);
}

/// A position (x, y) on our board.
pub const BoardPos = struct {
    x: i8,
    y: i8,

    /// Returns the position on the board at this location on the screen.
    pub fn fromPixelPos(pos: pixel.PixelPos) @This() {
        return .{
            .x = @intCast(@divFloor(pos.x, pixel.tile_size)),
            .y = @intCast(@divFloor(pos.y, pixel.tile_size)),
        };
    }

    /// Check whether this position is actually valid for indexing into the
    /// `Board`.
    pub fn isInBounds(this: @This()) bool {
        const x_in_bounds = 0 <= this.x and this.x < Board.size;
        const y_in_bounds = 0 <= this.y and this.y < Board.size;
        return (x_in_bounds and y_in_bounds);
    }

    /// Apply a motion to shift the given `BoardPos`, returning the
    /// resulting position (or `null` if it would be out-of-bounds).
    pub fn applyMotion(this: @This(), motion: Motion) ?@This() {
        const target: @This() = .{
            .x = this.x + motion.x,
            .y = this.y + motion.y,
        };
        return if (target.isInBounds()) target else null;
    }
};

test "BoardPos.fromPixelPos(n*size, n*size) returns (n, n)" {
    for (0..Board.size) |n| {
        const n_float: f32 = @floatFromInt(n);
        const tile_size_float: f32 = @floatFromInt(pixel.tile_size);

        // A pixel dead-centre in the middle of the intended tile.
        const pix: pixel.PixelPos = .{
            .x = @intFromFloat((n_float + 0.5) * tile_size_float),
            .y = @intFromFloat((n_float + 0.5) * tile_size_float),
        };
        const pos: BoardPos = .{ .x = @intCast(n), .y = @intCast(n) };

        try std.testing.expectEqual(BoardPos.fromPixelPos(pix), pos);
    }
}

/// The possible players of the game.
pub const Player = union(enum) {
    /// Typically called white in English; gōte (後手) in Japanese. Goes second.
    white,
    /// Typically called black in English; sente (先手) in Japanese. Goes first.
    black,

    /// Are the two players equal?
    pub fn eq(this: @This(), other: @This()) bool {
        return @intFromEnum(this) == @intFromEnum(other);
    }

    /// Are the two players different?
    pub fn not_eq(this: @This(), other: @This()) bool {
        return @intFromEnum(this) != @intFromEnum(other);
    }

    /// Changes this player to the other possibility - if this was `.white`
    /// before calling `swap()`, then it will be `.black` after, and vice
    /// versa.
    pub fn swap(this: @This()) @This() {
        return switch (this) {
            .white => .black,
            .black => .white,
        };
    }
};

/// The different sorts of shogi pieces. Includes promoted and non-promoted
/// pieces.
pub const Sort = enum {
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

/// A piece belonging to a player - this type combines a `Sort` and a
/// `Player` in one type.
pub const Piece = struct {
    player: Player,
    sort: Sort,

    /// The starting back row for a given player.
    pub fn backRow(player: Player) [Board.size]?@This() {
        return .{
            .{ .player = player, .sort = .lance },
            .{ .player = player, .sort = .knight },
            .{ .player = player, .sort = .silver },
            .{ .player = player, .sort = .gold },
            .{ .player = player, .sort = .king },
            .{ .player = player, .sort = .gold },
            .{ .player = player, .sort = .silver },
            .{ .player = player, .sort = .knight },
            .{ .player = player, .sort = .lance },
        };
    }

    /// The starting middle row for a given player.
    pub fn middleRow(player: Player) [Board.size]?@This() {
        const one = .{
            .player = player,
            .sort = switch (player) {
                .white => .rook,
                .black => .bishop,
            },
        };
        const two = .{
            .player = player,
            .sort = switch (player) {
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
                .sort = .pawn,
            },
        } ** Board.size;
    }
};

/// The empty hand, with every key intialized to zero.
const empty_hand: std.EnumMap(Sort, i8) = init: {
    var map: std.EnumMap(Sort, i8) = .{};

    for (@typeInfo(Sort).Enum.fields) |field| {
        map.put(@enumFromInt(field.value), 0);
    }

    break :init map;
};

/// This type represents the pure state of the board, and has some associated
/// functionalimodel.
pub const Board = struct {
    /// Which (if any) `Piece` is on each square/tile.
    tiles: [size][size]?Piece,

    /// Which pieces does each player have in hand?
    hand: struct {
        /// What pieces does white have in hand, and how many of each?
        white: std.EnumMap(Sort, i8),
        /// What pieces does black have in hand, and how many of each?
        black: std.EnumMap(Sort, i8),
    },

    /// The size of the board (i.e. its width/height).
    pub const size = 9;

    /// The initial / starting state of the board.
    pub const init: @This() = .{
        .tiles = .{
            // White's territory.
            Piece.backRow(.white),
            Piece.middleRow(.white),
            Piece.frontRow(.white),

            // No-mans land.
            .{null} ** size,
            .{null} ** size,
            .{null} ** size,

            // Black's territory.
            Piece.frontRow(.black),
            Piece.middleRow(.black),
            Piece.backRow(.black),
        },

        .hand = .{
            .white = empty_hand,
            .black = empty_hand,
        },
    };

    /// Get the `Piece` (if any) at the given position.
    pub fn get(this: @This(), pos: BoardPos) ?Piece {
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        return this.tiles[y][x];
    }

    /// Set (or delete) the `Piece` present at the given position.
    pub fn set(this: *@This(), pos: BoardPos, piece: ?Piece) void {
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        this.tiles[y][x] = piece;
    }

    /// Process the given `Move` by updating the board as appropriate.
    pub fn applyMove(this: *@This(), move: Move) void {
        const src_piece = this.get(move.pos) orelse return;
        const dest = move.pos.applyMotion(move.motion) orelse return;
        const dest_piece = this.get(dest);

        // Update the board.
        this.set(move.pos, null);
        this.set(dest, src_piece);

        // Add the captured piece (if any) to the players hand.
        const piece = dest_piece orelse return;
        const sort = piece.sort.demote();

        var hand: *std.EnumMap(Sort, i8) = undefined;
        if (src_piece.player == .white) {
            hand = &this.hand.white;
        } else {
            hand = &this.hand.black;
        }

        if (hand.getPtr(sort)) |count| {
            count.* += 1;
        }
    }
};
