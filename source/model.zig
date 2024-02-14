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

/// A valid move in the game. Can be either a 'basic' move (moving a piece from
/// one tile to another) or a drop.
pub const Move = union(enum) {
    /// A basic move - changing the position of some piece from one tile to
    /// another, possibly capturing something at the destination tile and
    /// possibly promoting along the way.
    basic: Basic,
    /// A piece was dropped onto the board.
    drop: Drop,

    /// A basic move.
    pub const Basic = struct {
        /// The initial location where the piece came from.
        from: BoardPos,
        /// The motion of the piece, relating to it's initial `BoardPos`.
        motion: Motion,
        /// Whether the moved piece was promoted in the course of this move.
        promoted: bool = false,
    };

    /// A piece drop.
    pub const Drop = struct {
        /// The destination of the dropped piece.
        pos: BoardPos,
        /// What sort of `Piece` was dropped.
        piece: Piece,
    };
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

    /// Whether this position is in the promotion zone for the given `Player`.
    pub fn isInPromotionZoneFor(this: @This(), player: Player) bool {
        return switch (player) {
            .white => 0 <= this.y and this.y < 3,
            .black => Board.size - 3 <= this.y and this.y < Board.size,
        };
    }
};

/// The possible players of the game.
pub const Player = union(enum) {
    /// Typically called white in English; gōte (後手) in Japanese. Goes second.
    white,
    /// Typically called black in English; sente (先手) in Japanese. Goes first.
    black,

    /// Whether or not these two players are the same.
    pub fn eq(this: @This(), other: @This()) bool {
        return @intFromEnum(this) == @intFromEnum(other);
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

    /// Whether or not these two sorts of pieces are the same.
    pub fn eq(this: @This(), other: @This()) bool {
        return @intFromEnum(this) == @intFromEnum(other);
    }

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

test "Sort.promote is idempotent" {
    for (@typeInfo(Sort).Enum.fields) |field| {
        const sort: Sort = @enumFromInt(field.value);
        const promoted_once = sort.promote();
        const promoted_twice = promoted_once.promote();
        std.testing.expectEqual(promoted_once, promoted_twice);
    }
}

test "Sort.demote is idempotent" {
    for (@typeInfo(Sort).Enum.fields) |field| {
        const sort: Sort = @enumFromInt(field.value);
        const demoted_once = sort.demote();
        const demoted_twice = demoted_once.demote();
        std.testing.expectEqual(demoted_once, demoted_twice);
    }
}

/// A piece belonging to a player - this type combines a `Sort` and a
/// `Player` in one type.
pub const Piece = struct {
    player: Player,
    sort: Sort,

    /// Whether or not these two pieces are the same.
    pub fn eq(this: @This(), other: @This()) bool {
        return this.player.eq(other.player) and this.sort.eq(other.sort);
    }
};

/// The pieces in a player's hand.
pub const Hand = std.EnumMap(Sort, i8);

/// The empty hand, with every key intialized to zero.
const empty_hand: Hand = init: {
    var map: Hand = .{};

    for (@typeInfo(Sort).Enum.fields) |field| {
        map.put(@enumFromInt(field.value), 0);
    }

    break :init map;
};

/// The starting back row for a given player.
pub fn backRankFor(player: Player) [Board.size]?Piece {
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
pub fn middleRankFor(player: Player) [Board.size]?Piece {
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
pub fn frontRankFor(player: Player) [Board.size]?Piece {
    const piece = .{ .player = player, .sort = .pawn };
    return .{piece} ** Board.size;
}

/// This type represents the pure state of the board, and has some associated
/// functionalimodel.
pub const Board = struct {
    /// Which (if any) `Piece` is on each square/tile.
    tiles: [size][size]?Piece,

    /// Which pieces does each player have in hand?
    hand: struct {
        /// What pieces does white have in hand, and how many of each?
        white: Hand,
        /// What pieces does black have in hand, and how many of each?
        black: Hand,
    },

    /// The size of the board (i.e. its width/height).
    pub const size = 9;

    /// The initial / starting state of the board.
    pub const init: @This() = .{
        .tiles = .{
            // White's territory.
            backRankFor(.white),
            middleRankFor(.white),
            frontRankFor(.white),

            // No-mans land.
            .{null} ** size,
            .{null} ** size,
            .{null} ** size,

            // Black's territory.
            frontRankFor(.black),
            middleRankFor(.black),
            backRankFor(.black),
        },

        .hand = .{
            .white = empty_hand,
            .black = empty_hand,
        },
    };

    /// Whether or not the numbered file has 1 or more pawns (just a plain
    /// pawn, not counting *promoted* pawns). The numbering is 0-indexed from
    /// left-to-right, the same as indices into `tiles`.
    pub fn fileHasPawnFor(this: @This(), file: usize, player: Player) bool {
        for (0..size) |rank| {
            const piece = this.tiles[rank][file] orelse continue;
            if (piece.player == player and piece.sort == .pawn) {
                return true;
            }
        }
        return false;
    }

    pub fn filesHavePawnFor(
        this: @This(),
        player: Player,
    ) std.bit_set.IntegerBitSet(u16) {
        var bit_set = std.bit_set.IntegerBitSet(u16).initEmpty();

        for (0..size) |file| {
            for (0..size) |rank| {
                const piece = this.tiles[rank][file] orelse continue;
                if (piece.player == player and piece.sort == .pawn) {
                    bit_set.set(file);
                    break;
                }
            }
        }

        return bit_set;
    }

    /// Get the `Hand` of the given player.
    pub fn handPtr(this: *@This(), player: Player) *Hand {
        return switch (player) {
            .black => &this.hand.black,
            .white => &this.hand.white,
        };
    }

    /// Get the `Piece` (if any) at the given position.
    pub fn get(this: @This(), pos: BoardPos) ?Piece {
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        return this.tiles[y][x];
    }

    /// Get a pointer into the `Piece` (if any) at the given position.
    pub fn getPtr(this: *@This(), pos: BoardPos) *?Piece {
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        return &this.tiles[y][x];
    }

    /// Set (or delete) the `Piece` present at the given position.
    pub fn set(this: *@This(), pos: BoardPos, piece: ?Piece) void {
        const x: usize = @intCast(pos.x);
        const y: usize = @intCast(pos.y);
        this.tiles[y][x] = piece;
    }

    /// Process the given `Move` by updating the board as appropriate. Returns
    /// `true` if the move was applied successfully, `false` otherwise.
    pub fn applyMove(this: *@This(), move: Move) bool {
        switch (move) {
            .basic => |basic| return this.applyMoveBasic(basic),
            .drop => |drop| return this.applyMoveDrop(drop),
        }
    }

    /// Process the given `Move.Drop` by updating the board as appropriate.
    /// Returns `true` if the move was applied successfully, `false` otherwise.
    pub fn applyMoveDrop(this: *@This(), move: Move.Drop) bool {
        const dest = this.getPtr(move.pos);
        const hand = this.handPtr(move.piece.player);
        const count = hand.getPtr(move.piece.sort) orelse return false;

        if (dest.* != null) return false;
        if (count.* < 1) return false;

        // Make sure to demote the piece, if it isn't already.
        var piece = move.piece;
        piece.sort = piece.sort.demote();

        dest.* = piece;
        count.* -= 1;

        return true;
    }

    /// Process the given `Move.Basic` by updating the board as appropriate.
    /// Returns `true` if the move was applied successfully, `false` otherwise.
    pub fn applyMoveBasic(this: *@This(), move: Move.Basic) bool {
        var src_piece = this.get(move.from) orelse return false;
        const dest = move.from.applyMotion(move.motion) orelse return false;
        const dest_piece = this.get(dest);

        if (move.promoted) {
            src_piece.sort = src_piece.sort.promote();
        }

        // Update the board.
        this.set(move.from, null);
        this.set(dest, src_piece);

        // Add the captured piece (if any) to the players hand.
        const hand = this.handPtr(src_piece.player);
        const piece = dest_piece orelse return true;
        const sort = piece.sort.demote();

        if (hand.getPtr(sort)) |count| {
            count.* += 1;
        }

        return true;
    }
};
