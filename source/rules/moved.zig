//! This module contains the logic for how each piece moves and what
//! constitutes a valid move. It has crossover with `model.zig`, but is
//! intended to handle the more complex rules, where 'model' contains just the
//! core types and basic functionality.

const checked = @import("checked.zig");
const model = @import("../model.zig");
const std = @import("std");
const Valid = @import("types.zig").Valid;

/// Errors than can occur while calculating piece movements.
pub const Error = std.mem.Allocator.Error;

var calls: u32 = 0;

/// Returns a list of all valid motions for the piece at the given position.
/// The caller is responsible for freeing the memory associated with the
/// returned `Motions`.
pub fn movementsFrom(
    args: struct {
        alloc: std.mem.Allocator,
        from: model.BoardPos,
        board: model.Board,
        test_check: bool = true,
    },
) Error!std.ArrayList(Valid.Movement) {
    const piece = args.board.get(args.from) orelse {
        return std.ArrayList(Valid.Movement).init(args.alloc);
    };

    calls += 1;
    std.debug.print("movementsFrom [{d}]: got here\n", .{calls});

    var direct_args: DirectArgs = .{
        .alloc = args.alloc,
        .from = args.from,
        .player = piece.player,
        .board = args.board,
        .motions = undefined,
        .test_check = args.test_check,
    };
    var ranged_args: RangedArgs = .{
        .alloc = args.alloc,
        .player = piece.player,
        .from = args.from,
        .board = args.board,
        .steps = undefined,
        .test_check = args.test_check,
    };

    switch (piece.sort) {
        .king => {
            direct_args.motions = &[_]model.Motion{
                .{ .x = 1, .y = 0 },  .{ .x = 1, .y = 1 },
                .{ .x = 0, .y = 1 },  .{ .x = -1, .y = 1 },
                .{ .x = -1, .y = 0 }, .{ .x = -1, .y = -1 },
                .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 },
            };
            return directMovementsFrom(direct_args);
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

            var all_moves = try directMovementsFrom(direct_args);
            errdefer all_moves.deinit();

            const ranged_moves = try rangedMovementsFromSteps(ranged_args);
            defer ranged_moves.deinit();

            try all_moves.appendSlice(ranged_moves.items);
            return all_moves;
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

            var all_moves = try directMovementsFrom(direct_args);
            errdefer all_moves.deinit();

            const ranged_moves = try rangedMovementsFromSteps(ranged_args);
            defer ranged_moves.deinit();

            try all_moves.appendSlice(ranged_moves.items);
            return all_moves;
        },

        .rook => {
            ranged_args.steps = &[_]model.Motion{
                .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 },
                .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 1 },
            };
            return rangedMovementsFromSteps(ranged_args);
        },

        .bishop => {
            ranged_args.steps = &[_]model.Motion{
                .{ .x = -1, .y = -1 }, .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 1 },  .{ .x = 1, .y = 1 },
            };
            return rangedMovementsFromSteps(ranged_args);
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
            return directMovementsFrom(direct_args);
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
            return directMovementsFrom(direct_args);
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
            return directMovementsFrom(direct_args);
        },

        .lance => {
            var motion: model.Motion = .{ .x = 0, .y = -1 };
            if (piece.player == .white) {
                motion.flipHoriz();
            }

            ranged_args.steps = &.{motion};
            return rangedMovementsFromSteps(ranged_args);
        },

        .pawn => {
            var motion: model.Motion = .{ .x = 0, .y = -1 };
            if (piece.player == .white) {
                motion.flipHoriz();
            }

            direct_args.motions = &.{motion};
            return directMovementsFrom(direct_args);
        },
    }
}

/// The arguments to `directMovementsFrom`.
const DirectArgs = struct {
    alloc: std.mem.Allocator,
    from: model.BoardPos,
    player: model.Player,
    board: model.Board,
    motions: []const model.Motion,
    test_check: bool = true,
};

/// Returns an array of possible `Motions` from the given position, by
/// filtering the given argument `motions` based on whether:
///
/// * The result of making that move would be in-bounds.
/// * The destination tile is vacant OR occupied by an opponent's piece.
/// * Making this move would not leave the player in check.
fn directMovementsFrom(
    args: DirectArgs,
) Error!std.ArrayList(Valid.Movement) {
    var moves = std.ArrayList(Valid.Movement).init(args.alloc);
    errdefer moves.deinit();

    for (args.motions) |motion| {
        const dest = args.from.applyMotion(motion) orelse continue;

        // We cannot capture our own pieces.
        if (args.board.get(dest)) |piece| {
            if (piece.player.eq(args.player)) continue;
        }

        if (args.test_check) {
            // We cannot make a move that would leave us in check
            var if_moved = args.board;
            const is_ok = if_moved.applyMoveBasic(.{
                .from = args.from,
                .motion = motion,
                .promoted = false,
            });
            std.debug.assert(is_ok);

            const causes_check =
                try checked.isInCheck(args.alloc, args.player, if_moved);
            if (causes_check) continue;
        }

        // If we got this far, then this move is okay.
        const could_promote =
            args.from.isInPromotionZoneFor(args.player) or
            dest.isInPromotionZoneFor(args.player);
        try moves.append(.{
            .motion = motion,
            .could_promote = could_promote,
        });
    }

    return moves;
}

/// The arguments to `rangedMovementsFromSteps`.
const RangedArgs = struct {
    alloc: std.mem.Allocator,
    from: model.BoardPos,
    player: model.Player,
    board: model.Board,
    steps: []const model.Motion,
    test_check: bool = true,
};

/// Returns an array of possible `Motions` from the given position. For each
/// step in the `steps` argument, applying the given step to the starting
/// `pos` as many times as possible until either:
///
/// * It hits a tile that is out-of-bounds.
/// * It hits a tile that is occupied by an opponent's piece.
///
/// Additionally, any motion which would leave the player in check is discarded
/// from the possibilities.
fn rangedMovementsFromSteps(
    args: RangedArgs,
) Error!std.ArrayList(Valid.Movement) {
    var moves = std.ArrayList(Valid.Movement).init(args.alloc);
    errdefer moves.deinit();

    for (args.steps) |step| {
        var cur_step = step;

        for (1..model.Board.size) |_| {
            const dest = args.from.applyMotion(cur_step) orelse break;
            const could_promote =
                args.from.isInPromotionZoneFor(args.player) or
                dest.isInPromotionZoneFor(args.player);

            if (args.test_check) {
                // We cannot make a move that would leave us in check.
                var if_moved = args.board;
                const is_ok = if_moved.applyMoveBasic(.{
                    .from = args.from,
                    .motion = cur_step,
                    .promoted = false,
                });
                std.debug.assert(is_ok);

                const causes_check =
                    try checked.isInCheck(args.alloc, args.player, if_moved);
                if (causes_check) break;
            }

            if (args.board.get(dest)) |piece| {
                // We cannot capture our own pieces.
                if (piece.player.eq(args.player)) break;

                // If we got here, then this move is okay.
                try moves.append(.{
                    .motion = cur_step,
                    .could_promote = could_promote,
                });

                // We cannot go any further, so must break the loop.
                break;
            } else {
                // If the tile is vacant, then this move is okay.
                try moves.append(.{
                    .motion = cur_step,
                    .could_promote = could_promote,
                });
            }

            cur_step.x += step.x;
            cur_step.y += step.y;
        }
    }

    return moves;
}
