//! This module contains the logic for how each piece moves and what
//! constitutes a valid move.

const std = @import("std");
const ty = @import("types.zig");

/// A collection of possible moves on the board.
pub const Moves = std.BoundedArray(ty.Move, max_moves);

/// An upper bound on the maximum number of possible moves that any piece
/// could have. The case which requires the most possible moves is dropping a
/// new piece onto a near-empty board.
const max_moves: usize = ty.Board.size * ty.Board.size;

/// Returns a list of all valid moves for the piece at the given position.
pub fn validMoves(pos: ty.BoardPos, board: ty.Board) Moves {
    const piece = board.get(pos) orelse {
        return Moves.init(0) catch unreachable;
    };

    var direct_args: DirectArgs = .{
        .pos = pos,
        .user = piece.player,
        .board = board,
        .moves = undefined,
    };
    var ranged_args: RangedArgs = .{
        .user = piece.player,
        .pos = pos,
        .board = board,
        .steps = undefined,
    };

    switch (piece.sort) {
        .king => {
            // TODO: handle 'check' conditions.
            direct_args.moves = &[_]ty.Move{
                .{ .x = 1, .y = 0 },  .{ .x = 1, .y = 1 },
                .{ .x = 0, .y = 1 },  .{ .x = -1, .y = 1 },
                .{ .x = -1, .y = 0 }, .{ .x = -1, .y = -1 },
                .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 },
            };
            return directMovesFrom(direct_args);
        },

        .promoted_rook => {
            ranged_args.steps = &[_]ty.Move{
                .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
            };
            direct_args.moves = &[_]ty.Move{
                .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
            };

            const direct_moves = directMovesFrom(direct_args);
            const ranged_moves = rangedMovesFromSteps(ranged_args);

            var all_moves = ranged_moves;
            for (direct_moves.slice()) |move| {
                all_moves.appendAssumeCapacity(move);
            }

            return all_moves;
        },

        .promoted_bishop => {
            ranged_args.steps = &[_]ty.Move{
                .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
            };
            direct_args.moves = &[_]ty.Move{
                .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
            };

            const direct_moves = directMovesFrom(direct_args);
            const ranged_moves = rangedMovesFromSteps(ranged_args);

            var all_moves = ranged_moves;
            for (direct_moves.slice()) |move| {
                all_moves.appendAssumeCapacity(move);
            }

            return all_moves;
        },

        .rook => {
            ranged_args.steps = &[_]ty.Move{
                .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
            };
            return rangedMovesFromSteps(ranged_args);
        },

        .bishop => {
            ranged_args.steps = &[_]ty.Move{
                .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
            };
            return rangedMovesFromSteps(ranged_args);
        },

        .gold,
        .promoted_silver,
        .promoted_knight,
        .promoted_lance,
        .promoted_pawn,
        => {
            var moves = [_]ty.Move{
                .{ .x = -1, .y = -1 }, .{ .x = 0, .y = -1 },
                .{ .x = 1, .y = -1 },  .{ .x = -1, .y = 0 },
                .{ .x = 1, .y = 0 },   .{ .x = 0, .y = 1 },
            };

            if (piece.player == .white) {
                for (&moves) |*move| {
                    move.flipHoriz();
                }
            }

            direct_args.moves = &moves;
            return directMovesFrom(direct_args);
        },

        .silver => {
            var moves = [_]ty.Move{
                .{ .x = -1, .y = -1 }, .{ .x = 0, .y = -1 },
                .{ .x = 1, .y = -1 },  .{ .x = -1, .y = 1 },
                .{ .x = 1, .y = 1 },
            };

            if (piece.player == .white) {
                for (&moves) |*move| {
                    move.flipHoriz();
                }
            }

            direct_args.moves = &moves;
            return directMovesFrom(direct_args);
        },

        .knight => {
            var moves = [_]ty.Move{
                .{ .x = 1, .y = -2 }, .{ .x = -1, .y = -2 },
            };

            if (piece.player == .white) {
                for (&moves) |*move| {
                    move.flipHoriz();
                }
            }

            direct_args.moves = &moves;
            return directMovesFrom(direct_args);
        },

        .lance => {
            var move: ty.Move = .{ .x = 0, .y = -1 };
            if (piece.player == .white) {
                move.flipHoriz();
            }

            ranged_args.steps = &.{move};
            return rangedMovesFromSteps(ranged_args);
        },

        .pawn => {
            var move: ty.Move = .{ .x = 0, .y = -1 };
            if (piece.player == .white) {
                move.flipHoriz();
            }

            direct_args.moves = &.{move};
            return directMovesFrom(direct_args);
        },
    }
}

/// The arguments to `directMovesFrom`.
const DirectArgs = struct {
    pos: ty.BoardPos,
    user: ty.Player,
    board: ty.Board,
    moves: []const ty.Move,
};

/// Returns an array of possible `Move`s from the given position, by filtering
/// the given argument `moves` based on whether the result of making that move
/// would be in-bounds and the destination tile is vacant / occupied by an
/// opponent's piece.
fn directMovesFrom(args: DirectArgs) Moves {
    var array = Moves.init(0) catch unreachable;

    for (args.moves) |move| {
        const dest = args.pos.makeMove(move) orelse continue;

        if (args.board.get(dest)) |piece| {
            // If there is an opponent's piece in the way, that is ok.
            const owner_is_opp = ty.Player.not_eq(piece.player, args.user);
            if (owner_is_opp) {
                array.appendAssumeCapacity(move);
            }
        } else {
            // If the tile is vacant, that is also ok.
            array.appendAssumeCapacity(move);
        }
    }

    return array;
}

/// The arguments to `rangedMovesFromSteps`.
const RangedArgs = struct {
    pos: ty.BoardPos,
    user: ty.Player,
    board: ty.Board,
    steps: []const ty.Move,
};

/// Returns an array of possible `Move`s from the given position. For each
/// step in the `steps` argument, applying the given step to the starting
/// `pos` as many times as possible until it hits a tile that is out-of-bounds
/// or is occupied by an opponent's piece.
fn rangedMovesFromSteps(args: RangedArgs) Moves {
    var array = Moves.init(0) catch unreachable;

    for (args.steps) |step| {
        var cur_step = step;

        for (1..ty.Board.size) |_| {
            const dest = args.pos.makeMove(cur_step) orelse continue;

            if (args.board.get(dest)) |piece| {
                // If there is an opponent's piece in the way, that is ok.
                const owner_is_opp = ty.Player.not_eq(piece.player, args.user);
                if (owner_is_opp) {
                    array.appendAssumeCapacity(cur_step);
                }

                // We should break the loop no matter whose piece is in the
                // way, we can go no further.
                break;
            } else {
                // If the tile is vacant, that is also ok.
                array.appendAssumeCapacity(cur_step);
            }

            cur_step.x += step.x;
            cur_step.y += step.y;
        }
    }

    return array;
}
