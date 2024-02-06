//! This module contains the logic for how each piece moves and what
//! constitutes a valid move.

const std = @import("std");
const model = @import("model.zig");

/// A collection of possible moves on the board.
pub const Moves = struct {
    pos: model.BoardPos,
    motions: Motions,
};

/// A collection of possible motions on the board.
pub const Motions = std.BoundedArray(model.Motion, max_moves);

/// An upper bound on the maximum number of possible moves/motions that any
/// piece could have. The case which requires the most possible moves is
/// dropping a new piece onto a near-empty board.
pub const max_moves: usize = model.Board.size * model.Board.size;

/// Returns a list of all valid moves for the piece at the given position.
pub fn validMoves(pos: model.BoardPos, board: model.Board) Moves {
    return .{
        .pos = pos,
        .motions = validMotions(pos, board),
    };
}

/// Returns a list of all valid motions for the piece at the given position.
pub fn validMotions(pos: model.BoardPos, board: model.Board) Motions {
    const piece = board.get(pos) orelse {
        return Motions.init(0) catch unreachable;
    };

    var direct_args: DirectArgs = .{
        .pos = pos,
        .user = piece.player,
        .board = board,
        .motions = undefined,
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
            direct_args.motions = &[_]model.Motion{
                .{ .x = 1, .y = 0 },  .{ .x = 1, .y = 1 },
                .{ .x = 0, .y = 1 },  .{ .x = -1, .y = 1 },
                .{ .x = -1, .y = 0 }, .{ .x = -1, .y = -1 },
                .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 },
            };
            return directMotionsFrom(direct_args);
        },

        .promoted_rook => {
            ranged_args.steps = &[_]model.Motion{
                .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
            };
            direct_args.motions = &[_]model.Motion{
                .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
            };

            const direct_motions = directMotionsFrom(direct_args);
            const ranged_motions = rangedMotionsFromSteps(ranged_args);

            var all_motions = ranged_motions;
            for (direct_motions.slice()) |motion| {
                all_motions.appendAssumeCapacity(motion);
            }

            return all_motions;
        },

        .promoted_bishop => {
            ranged_args.steps = &[_]model.Motion{
                .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
            };
            direct_args.motions = &[_]model.Motion{
                .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
            };

            const direct_motions = directMotionsFrom(direct_args);
            const ranged_motions = rangedMotionsFromSteps(ranged_args);

            var all_motions = ranged_motions;
            for (direct_motions.slice()) |motion| {
                all_motions.appendAssumeCapacity(motion);
            }

            return all_motions;
        },

        .rook => {
            ranged_args.steps = &[_]model.Motion{
                .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
            };
            return rangedMotionsFromSteps(ranged_args);
        },

        .bishop => {
            ranged_args.steps = &[_]model.Motion{
                .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
            };
            return rangedMotionsFromSteps(ranged_args);
        },

        .gold,
        .promoted_silver,
        .promoted_knight,
        .promoted_lance,
        .promoted_pawn,
        => {
            var motions = [_]model.Motion{
                .{ .x = -1, .y = -1 }, .{ .x = 0, .y = -1 },
                .{ .x = 1, .y = -1 },  .{ .x = -1, .y = 0 },
                .{ .x = 1, .y = 0 },   .{ .x = 0, .y = 1 },
            };

            if (piece.player == .white) {
                for (&motions) |*motion| {
                    motion.flipHoriz();
                }
            }

            direct_args.motions = &motions;
            return directMotionsFrom(direct_args);
        },

        .silver => {
            var motions = [_]model.Motion{
                .{ .x = -1, .y = -1 }, .{ .x = 0, .y = -1 },
                .{ .x = 1, .y = -1 },  .{ .x = -1, .y = 1 },
                .{ .x = 1, .y = 1 },
            };

            if (piece.player == .white) {
                for (&motions) |*motion| {
                    motion.flipHoriz();
                }
            }

            direct_args.motions = &motions;
            return directMotionsFrom(direct_args);
        },

        .knight => {
            var motions = [_]model.Motion{
                .{ .x = 1, .y = -2 }, .{ .x = -1, .y = -2 },
            };

            if (piece.player == .white) {
                for (&motions) |*motion| {
                    motion.flipHoriz();
                }
            }

            direct_args.motions = &motions;
            return directMotionsFrom(direct_args);
        },

        .lance => {
            var motion: model.Motion = .{ .x = 0, .y = -1 };
            if (piece.player == .white) {
                motion.flipHoriz();
            }

            ranged_args.steps = &.{motion};
            return rangedMotionsFromSteps(ranged_args);
        },

        .pawn => {
            var motion: model.Motion = .{ .x = 0, .y = -1 };
            if (piece.player == .white) {
                motion.flipHoriz();
            }

            direct_args.motions = &.{motion};
            return directMotionsFrom(direct_args);
        },
    }
}

/// The arguments to `directMotionsFrom`.
const DirectArgs = struct {
    pos: model.BoardPos,
    user: model.Player,
    board: model.Board,
    motions: []const model.Motion,
};

/// Returns an array of possible `Motions` from the given position, by filtering
/// the given argument `motions` based on whether the result of making that move
/// would be in-bounds and the destination tile is vacant / occupied by an
/// opponent's piece.
fn directMotionsFrom(args: DirectArgs) Motions {
    var motions = Motions.init(0) catch unreachable;

    for (args.motions) |motion| {
        const dest = args.pos.applyMotion(motion) orelse continue;

        if (args.board.get(dest)) |piece| {
            // If there is an opponent's piece in the way, that is ok.
            const owner_is_opp = piece.player.not_eq(args.user);
            if (owner_is_opp) {
                motions.appendAssumeCapacity(motion);
            }
        } else {
            // If the tile is vacant, that is also ok.
            motions.appendAssumeCapacity(motion);
        }
    }

    return motions;
}

/// The arguments to `rangedMotionsFromSteps`.
const RangedArgs = struct {
    pos: model.BoardPos,
    user: model.Player,
    board: model.Board,
    steps: []const model.Motion,
};

/// Returns an array of possible `Motions` from the given position. For each
/// step in the `steps` argument, applying the given step to the starting
/// `pos` as many times as possible until it hits a tile that is out-of-bounds
/// or is occupied by an opponent's piece.
fn rangedMotionsFromSteps(args: RangedArgs) Motions {
    var motions = Motions.init(0) catch unreachable;

    for (args.steps) |step| {
        var cur_step = step;

        for (1..model.Board.size) |_| {
            const dest = args.pos.applyMotion(cur_step) orelse continue;

            if (args.board.get(dest)) |piece| {
                // If there is an opponent's piece in the way, that is ok.
                const owner_is_opp = piece.player.not_eq(args.user);
                if (owner_is_opp) {
                    motions.appendAssumeCapacity(cur_step);
                }

                // We should break the loop no matter whose piece is in the
                // way, we can go no further.
                break;
            } else {
                // If the tile is vacant, that is also ok.
                motions.appendAssumeCapacity(cur_step);
            }

            cur_step.x += step.x;
            cur_step.y += step.y;
        }
    }

    return motions;
}
