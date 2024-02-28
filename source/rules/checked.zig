//! Implements tests for whether or not a player is in check or checkmate.

const model = @import("../model.zig");
const std = @import("std");
const valid = @import("valid.zig");

/// Possible errors that can occur while calculating check(mate).
pub const Error = std.mem.Allocator.Error;

/// Returns whether the king for the given player is in check. In other words,
/// whether it could be captured by a piece already on the board if the
/// opposite player was able to move.
pub fn isInCheck(
    alloc: std.mem.Allocator,
    player: model.Player,
    board: model.Board,
) Error!bool {
    const king = .{ .player = player, .sort = .king };
    const pos = board.find(king) orelse return false;

    // It's important we set `.test_check = false` here to avoid infinite
    // recursion. It is correct to do so, as we are searching for moves by the
    // other player which would capture this player's king - as such, they
    // would end the game before the other player could suffer the consequences
    // of their own check.
    var moves = try valid.movesBasicFor(.{
        .alloc = alloc,
        .player = player.swap(),
        .board = board,
        .test_check = false,
    });
    defer moves.deinit();

    var iter = moves.map.iterator();
    while (iter.next()) |entry| {
        const from = entry.key_ptr.*;
        const movements = entry.value_ptr.*;
        for (movements.items) |item| {
            const dest = from.applyMotion(item.motion) orelse continue;
            if (dest.eq(pos)) {
                return true;
            }
        }
    }

    return false;
}

/// Returns whether the king for the given player is in checkmate - in other
/// words, both of these conditions hold:
///
/// * Their king is in check.
/// * No move they can make puts their king out of check.
pub fn isInCheckMate(
    alloc: std.mem.Allocator,
    player: model.Player,
    board: model.Board,
) Error!bool {
    const in_check = try isInCheck(alloc, player, board);
    if (!in_check) return false;

    var moves = try valid.movesFor(.{
        .alloc = alloc,
        .player = player,
        .board = board,
        .test_check = true,
    });
    defer moves.deinit();

    // If there is any move which results in us not being in check (which we
    // are filtering on by setting `.test_check = true`), then we are not
    // in-fact in checkmate.
    const count = moves.basics.map.count() + moves.drops.map.count();
    return count > 0;
}
