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
    const player_piece = board.get(pos) orelse {
        return Moves.init(0) catch unreachable;
    };

    var direct_args: DirectArgs = .{
        .pos = pos,
        .player = player_piece.player,
        .board = board,
        .moves = undefined,
    };
    var ranged_args: RangedArgs = .{
        .player = player_piece.player,
        .pos = pos,
        .board = board,
        .steps = undefined,
    };

    switch (player_piece.piece) {
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
            var ranged_moves = rangedMovesFromSteps(ranged_args);

            for (direct_moves.slice()) |move| {
                ranged_moves.appendAssumeCapacity(move);
            }

            return ranged_moves;
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
            var ranged_moves = rangedMovesFromSteps(ranged_args);

            for (direct_moves.slice()) |move| {
                ranged_moves.appendAssumeCapacity(move);
            }

            return ranged_moves;
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

            if (player_piece.player == .white) {
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

            if (player_piece.player == .white) {
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

            if (player_piece.player == .white) {
                for (&moves) |*move| {
                    move.flipHoriz();
                }
            }

            direct_args.moves = &moves;
            return directMovesFrom(direct_args);
        },

        .lance => {
            var move: ty.Move = .{ .x = 0, .y = -1 };
            if (player_piece.player == .white) {
                move.flipHoriz();
            }

            direct_args.moves = &.{move};
            return rangedMovesFromSteps(ranged_args);
        },

        .pawn => {
            var move: ty.Move = .{ .x = 0, .y = -1 };
            if (player_piece.player == .white) {
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
    player: ty.Player,
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
        if (args.pos.makeMove(move)) |dest| {
            if (args.board.get(dest)) |piece| {
                // If there is an opponent's piece in the way, that is ok.
                const owner = @intFromEnum(piece.player);
                const player = @intFromEnum(args.player);
                if (owner != player) {
                    array.appendAssumeCapacity(move);
                }
            } else {
                // If the tile is vacant, that is also ok.
                array.appendAssumeCapacity(move);
            }
        }
    }

    return array;
}

/// The arguments to `rangedMovesFromSteps`.
const RangedArgs = struct {
    pos: ty.BoardPos,
    player: ty.Player,
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
            if (args.pos.makeMove(cur_step)) |dest| {
                if (args.board.get(dest)) |piece| {
                    // If there is an opponent's piece in the way, that is ok.
                    const owner = @intFromEnum(piece.player);
                    const player = @intFromEnum(args.player);
                    if (owner != player) {
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
    }

    return array;
}
