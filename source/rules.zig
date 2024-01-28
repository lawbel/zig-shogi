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

    /// Is this move valid, considering the state of the `ty.Board` for this
    /// player and the source position on the board.
    pub fn isValid(
        this: @This(),
        pos: ty.BoardPos,
        player: ty.Player,
        board: ty.Board,
    ) bool {
        const valid = validMovesFor(player, pos, board);

        for (valid.slice()) |move| {
            if (move.x == this.x and move.y == this.y) {
                return true;
            }
        }

        return false;
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

/// Returns a list of all valid moves for the piece at the given `ty.BoardPos`,
/// assuming that the piece belongs to black.
fn validMovesForBlack(pos: ty.BoardPos, board: ty.Board) Moves {
    const player_piece = board.get(pos) orelse {
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

        .promoted_rook => {
            var ranged_moves = rangedMovesFromSteps(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
                },
            );
            const direct_moves = directMovesFrom(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                    .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
                },
            );
            for (direct_moves.slice()) |move| {
                ranged_moves.appendAssumeCapacity(move);
            }
            return ranged_moves;
        },

        .promoted_bishop => {
            var ranged_moves = rangedMovesFromSteps(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                    .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
                },
            );
            const direct_moves = directMovesFrom(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
                },
            );
            for (direct_moves.slice()) |move| {
                ranged_moves.appendAssumeCapacity(move);
            }
            return ranged_moves;
        },

        .rook => {
            return rangedMovesFromSteps(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
                },
            );
        },

        .bishop => {
            return rangedMovesFromSteps(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                    .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
                },
            );
        },

        .gold,
        .promoted_silver,
        .promoted_knight,
        .promoted_lance,
        .promoted_pawn,
        => {
            return directMovesFrom(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 0, .y = -1 },
                    .{ .x = 1, .y = -1 },  .{ .x = -1, .y = 0 },
                    .{ .x = 1, .y = 0 },   .{ .x = 0, .y = 1 },
                },
            );
        },

        .silver => {
            return directMovesFrom(
                pos,
                board,
                &[_]Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 0, .y = -1 },
                    .{ .x = 1, .y = -1 },  .{ .x = -1, .y = 1 },
                    .{ .x = 1, .y = 1 },
                },
            );
        },

        .knight => {
            return directMovesFrom(
                pos,
                board,
                &[_]Move{
                    .{ .x = 1, .y = -2 }, .{ .x = -1, .y = -2 },
                },
            );
        },

        .lance => {
            return rangedMovesFromSteps(
                pos,
                board,
                &[_]Move{
                    .{ .x = 0, .y = -1 },
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
    }
}

/// Returns an array of possible `Move`s from the given position, by filtering
/// the given argument `moves` based on whether the result of making that move
/// would be in-bounds and the destination tile is vacant.
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
            if (board.get(dest) == null) {
                array.appendAssumeCapacity(move);
            }
        }
    }

    return array;
}

/// Returns an array of possible `Move`s from the given position. For each
/// step in the `steps` argument, applying the given step to the starting
/// `pos` as many times as possible until it hits a tile that is out-of-bounds
/// or is occupied by another piece.
fn rangedMovesFromSteps(
    pos: ty.BoardPos,
    board: ty.Board,
    steps: []const Move,
) Moves {
    var array = Moves.init(0) catch unreachable;

    for (steps) |step| {
        var cur_step = step;

        for (1..ty.Board.size) |_| {
            if (pos.makeMove(cur_step)) |dest| {
                if (board.get(dest) == null) {
                    array.appendAssumeCapacity(cur_step);
                } else {
                    break;
                }

                cur_step.x += step.x;
                cur_step.y += step.y;
            }
        }
    }

    return array;
}
