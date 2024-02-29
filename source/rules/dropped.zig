//! Implements the rules for where a player is allowed to drop a given piece
//! on the board.

const checked = @import("checked.zig");
const model = @import("../model.zig");
const promoted = @import("promoted.zig");
const std = @import("std");

/// Possible errors that can occur while calculating piece drops.
pub const Error = std.mem.Allocator.Error;

/// Returns a list of positions on the board where the given `model.Piece`
/// could be dropped.
pub fn possibleDropsOf(
    alloc: std.mem.Allocator,
    piece: model.Piece,
    board: model.Board,
) Error!std.ArrayList(model.BoardPos) {
    return switch (piece.sort.demote()) {
        .pawn => pawnDropsFor(alloc, piece.player, board),
        else => dropsOnEmptyTiles(alloc, piece, board),
    };
}

/// Returns a list of empty positions on the board - positions where any piece
/// could be dropped (except for pawns, which are handled by `pawnDropsFor`).
///
/// Forbids dropping a piece on the last few ranks, if it would have no moves
/// available. This restriction applies to pawns, lances and knights.
pub fn dropsOnEmptyTiles(
    alloc: std.mem.Allocator,
    piece: model.Piece,
    board: model.Board,
) Error!std.ArrayList(model.BoardPos) {
    std.debug.assert(piece.sort != .pawn);

    var tiles = std.ArrayList(model.BoardPos).init(alloc);
    errdefer tiles.deinit();

    for (board.tiles, 0..) |row, y| {
        const y_pos: i8 = @intCast(y);
        if (promoted.mustPromoteAtRank(piece, y_pos)) continue;

        for (row, 0..) |dest, x| {
            if (dest != null) continue;

            const x_pos: i8 = @intCast(x);
            const pos = .{ .x = x_pos, .y = y_pos };
            try tiles.append(pos);
        }
    }

    return tiles;
}

/// Returns a list of empty positions on the board where a pawn could be
/// dropped by the given `model.Player`.
///
/// * This accounts for the double pawn rule - a player cannot drop a pawn in
///   such a way that they would have two un-promoted pawns on the same file.
/// * It also forbids dropping a pawn on the last rank (from the given player's
///   perspective), as doing so would leave it with no valid moves.
/// * It does not allow dropping a pawn, if that would lead to an immediate
///   checkmate of the other player. (Checks are okay, only checkmates are
///   forbidden.)
pub fn pawnDropsFor(
    alloc: std.mem.Allocator,
    player: model.Player,
    board: model.Board,
) Error!std.ArrayList(model.BoardPos) {
    const has_pawn = board.filesHavePawnFor(player);
    const pawn = .{ .sort = .pawn, .player = player };
    var possible = std.ArrayList(model.BoardPos).init(alloc);
    errdefer possible.deinit();

    for (0..model.Board.size) |x| {
        if (has_pawn.isSet(x)) continue;

        for (0..model.Board.size) |y| {
            const x_pos: i8 = @intCast(x);
            const y_pos: i8 = @intCast(y);
            if (promoted.mustPromoteAtRank(pawn, y_pos)) continue;

            const pos = .{ .x = x_pos, .y = y_pos };
            if (board.get(pos) != null) continue;

            var if_dropped = board;
            const drop = .{ .pos = pos, .piece = pawn };
            const is_ok = if_dropped.applyMoveDrop(drop);
            std.debug.assert(is_ok);

            const causes_checkmate =
                try checked.isInCheckMate(alloc, player.swap(), if_dropped);
            if (causes_checkmate) continue;

            try possible.append(pos);
        }
    }

    return possible;
}
