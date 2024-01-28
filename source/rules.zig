//! This module contains the logic for how each piece moves and what
//! constitutes a valid move.

const std = @import("std");
const ty = @import("types.zig");

/// A vector `(x, y)` representing a move on our board.
pub const Move = struct {
    x: i8,
    y: i8,

    /// Swap this move to be valid for the opposite player (by flipping it
    /// about the horizontal).
    fn swapPlayer(this: @This()) @This() {
        return .{
            .x = this.x,
            .y = -this.y,
        };
    }
};

/// A collection of possible moves on the board.
pub const Moves = std.BoundedArray(Move, max_moves);

/// An upper bound on the maximum number of possible moves that any piece
/// could have. The case which requires the most possible moves is dropping a
/// new piece onto a near-empty board.
const max_moves: usize = ty.Board.size * ty.Board.size;

/// Returns a list of all valid moves for the given `ty.Player`.
pub fn validMovesFor(
    player: ty.Player,
    pos: ty.BoardPos,
    board: ty.Board,
) Moves {
    var moves = validMovesForBlack(pos, board);

    // If there are no valid moves, return the empty array now.
    if (moves.len == 0) {
        return moves;
    }

    if (player == .white) {
        for (0..moves.len - 1) |i| {
            const swapped = moves.get(i).swapPlayer();
            moves.set(i, swapped);
        }
    }

    return moves;
}

fn validMovesForBlack(pos: ty.BoardPos, board: ty.Board) Moves {
    const x: usize = @intCast(pos.x);
    const y: usize = @intCast(pos.y);
    const player_piece = board.tiles[y][x] orelse {
        return Moves.init(0) catch unreachable;
    };

    switch (player_piece.piece) {
        .king => {
            // TODO: handle 'check' conditions.
            return directMovesFrom(
                pos,
                board,
                &[_]Move{
                    .{ .x = 1, .y = 0 },  .{ .x = 1, .y = 1 },
                    .{ .x = 0, .y = 1 },  .{ .x = -1, .y = 1 },
                    .{ .x = -1, .y = 0 }, .{ .x = -1, .y = -1 },
                    .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 },
                },
            );
        },

        .pawn => {
            return directMovesFrom(
                pos,
                board,
                &[_]Move{
                    .{ .x = 0, .y = -1 },
                },
            );
        },

        else => unreachable, // TODO: implement.
    }
}

fn directMovesFrom(
    pos: ty.BoardPos,
    board: ty.Board,
    moves: []const Move,
) Moves {
    var array = Moves.init(0) catch unreachable;

    // If the move would be in-bounds, and there's not a piece in the
    // way, then it is a possible move.
    for (moves) |move| {
        if (pos.makeMove(move)) |dest| {
            const y: usize = @intCast(dest.y);
            const x: usize = @intCast(dest.x);
            if (board.tiles[y][x] == null) {
                array.appendAssumeCapacity(move);
            }
        }
    }

    return array;
}
