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

    switch (player_piece.piece) {
        .king => {
            // TODO: handle 'check' conditions.
            return directMovesFrom(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .moves = &[_]ty.Move{
                    .{ .x = 1, .y = 0 },  .{ .x = 1, .y = 1 },
                    .{ .x = 0, .y = 1 },  .{ .x = -1, .y = 1 },
                    .{ .x = -1, .y = 0 }, .{ .x = -1, .y = -1 },
                    .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 },
                },
            });
        },

        .promoted_rook => {
            var ranged_moves = rangedMovesFromSteps(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .steps = &[_]ty.Move{
                    .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
                },
            });
            const direct_moves = directMovesFrom(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .moves = &[_]ty.Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                    .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
                },
            });
            for (direct_moves.slice()) |move| {
                ranged_moves.appendAssumeCapacity(move);
            }
            return ranged_moves;
        },

        .promoted_bishop => {
            var ranged_moves = rangedMovesFromSteps(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .steps = &[_]ty.Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                    .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
                },
            });
            const direct_moves = directMovesFrom(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .moves = &[_]ty.Move{
                    .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
                },
            });
            for (direct_moves.slice()) |move| {
                ranged_moves.appendAssumeCapacity(move);
            }
            return ranged_moves;
        },

        .rook => {
            return rangedMovesFromSteps(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .steps = &[_]ty.Move{
                    .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
                },
            });
        },

        .bishop => {
            return rangedMovesFromSteps(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .steps = &[_]ty.Move{
                    .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                    .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
                },
            });
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
            return directMovesFrom(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .moves = &moves,
            });
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
            return directMovesFrom(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .moves = &moves,
            });
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
            return directMovesFrom(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .moves = &moves,
            });
        },

        .lance => {
            var move = ty.Move{ .x = 0, .y = -1 };
            if (player_piece.player == .white) {
                move.flipHoriz();
            }
            return rangedMovesFromSteps(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .steps = &.{move},
            });
        },

        .pawn => {
            var move = ty.Move{ .x = 0, .y = -1 };
            if (player_piece.player == .white) {
                move.flipHoriz();
            }
            return directMovesFrom(.{
                .player = player_piece.player,
                .pos = pos,
                .board = board,
                .moves = &.{move},
            });
        },
    }
}

/// Returns an array of possible `Move`s from the given position, by filtering
/// the given argument `moves` based on whether the result of making that move
/// would be in-bounds and the destination tile is vacant / occupied by an
/// opponent's piece.
fn directMovesFrom(
    args: struct {
        pos: ty.BoardPos,
        player: ty.Player,
        board: ty.Board,
        moves: []const ty.Move,
    },
) Moves {
    var array = Moves.init(0) catch unreachable;

    for (args.moves) |move| {
        if (args.pos.makeMove(move)) |dest| {
            if (args.board.get(dest)) |piece| {
                // If there is an opponent's piece in the way, that is ok.
                if (@intFromEnum(piece.player) != @intFromEnum(args.player)) {
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

/// Returns an array of possible `Move`s from the given position. For each
/// step in the `steps` argument, applying the given step to the starting
/// `pos` as many times as possible until it hits a tile that is out-of-bounds
/// or is occupied by an opponent's piece.
fn rangedMovesFromSteps(
    args: struct {
        pos: ty.BoardPos,
        player: ty.Player,
        board: ty.Board,
        steps: []const ty.Move,
    },
) Moves {
    var array = Moves.init(0) catch unreachable;

    for (args.steps) |step| {
        var cur_step = step;

        for (1..ty.Board.size) |_| {
            if (args.pos.makeMove(cur_step)) |dest| {
                if (args.board.get(dest)) |piece| {
                    // If there is an opponent's piece in the way, that is ok.
                    if (@intFromEnum(piece.player) !=
                        @intFromEnum(args.player))
                    {
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
