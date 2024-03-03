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
    args: struct {
        alloc: std.mem.Allocator,
        piece: model.Piece,
        board: model.Board,
        test_check: bool = true,
    },
) Error!std.ArrayList(model.BoardPos) {
    return switch (args.piece.sort.demote()) {
        .pawn => pawnDropsFor(.{
            .alloc = args.alloc,
            .player = args.piece.player,
            .board = args.board,
            .test_check = args.test_check,
        }),
        else => dropsOnEmptyTiles(.{
            .alloc = args.alloc,
            .piece = args.piece,
            .board = args.board,
            .test_check = args.test_check,
        }),
    };
}

/// Returns a list of empty positions on the board - positions where any piece
/// could be dropped (except for pawns, which are handled by `pawnDropsFor`).
///
/// Forbids dropping a piece on the last few ranks, if it would have no moves
/// available. This restriction applies to pawns, lances and knights.
pub fn dropsOnEmptyTiles(
    args: struct {
        alloc: std.mem.Allocator,
        piece: model.Piece,
        board: model.Board,
        test_check: bool = true,
    },
) Error!std.ArrayList(model.BoardPos) {
    std.debug.assert(args.piece.sort != .pawn);

    var tiles = std.ArrayList(model.BoardPos).init(args.alloc);
    errdefer tiles.deinit();

    for (args.board.tiles, 0..) |row, y| {
        const y_pos: i8 = @intCast(y);
        if (promoted.mustPromoteAtRank(args.piece, y_pos)) continue;

        for (row, 0..) |dest, x| {
            if (dest != null) continue;

            const x_pos: i8 = @intCast(x);
            const pos = .{ .x = x_pos, .y = y_pos };

            if (args.test_check) {
                var if_dropped = args.board;
                const drop = .{ .pos = pos, .piece = args.piece };
                const is_ok = if_dropped.applyMoveDrop(drop);
                std.debug.assert(is_ok);

                const leaves_in_check = try checked.isInCheck(
                    args.alloc,
                    args.piece.player,
                    if_dropped,
                );
                if (leaves_in_check) continue;
            }

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
    args: struct {
        alloc: std.mem.Allocator,
        player: model.Player,
        board: model.Board,
        test_check: bool = true,
    },
) Error!std.ArrayList(model.BoardPos) {
    const has_pawn = args.board.filesHavePawnFor(args.player);
    const pawn = .{ .sort = .pawn, .player = args.player };
    var possible = std.ArrayList(model.BoardPos).init(args.alloc);
    errdefer possible.deinit();

    for (0..model.Board.size) |x| {
        if (has_pawn.isSet(x)) continue;

        for (0..model.Board.size) |y| {
            const x_pos: i8 = @intCast(x);
            const y_pos: i8 = @intCast(y);
            if (promoted.mustPromoteAtRank(pawn, y_pos)) continue;

            const pos = .{ .x = x_pos, .y = y_pos };
            if (args.board.get(pos) != null) continue;

            var if_dropped = args.board;
            const drop = .{ .pos = pos, .piece = pawn };
            const is_ok = if_dropped.applyMoveDrop(drop);
            std.debug.assert(is_ok);

            if (args.test_check) {
                const leaves_in_check = try checked.isInCheck(
                    args.alloc,
                    args.player,
                    if_dropped,
                );
                if (leaves_in_check) continue;
            }

            const causes_checkmate = try checked.isInCheckMate(
                args.alloc,
                args.player.swap(),
                if_dropped,
            );
            if (causes_checkmate) continue;

            try possible.append(pos);
        }
    }

    return possible;
}

test "pawn drop can check opponent's king" {
    const alloc = std.testing.allocator;

    const player: model.Player = .black;
    const opponent: model.Player = player.swap();
    const expected_drop: model.Move.Drop = .{
        .piece = .{ .player = player, .sort = .pawn },
        .pos = .{ .x = 4, .y = 5 },
    };
    const board: model.Board = init: {
        var stage = model.Board.empty;
        stage.getHandPtr(player).put(.pawn, 1);
        stage.tiles[4][4] = .{ .player = opponent, .sort = .king };
        break :init stage;
    };

    const all_drops = try pawnDropsFor(.{
        .alloc = alloc,
        .player = player,
        .board = board,
        .test_check = true,
    });
    defer all_drops.deinit();

    var expected_drop_in_options = false;
    for (all_drops.items) |pos| {
        if (pos.eq(expected_drop.pos)) {
            expected_drop_in_options = true;
            break;
        }
    }

    try std.testing.expect(expected_drop_in_options);

    const expected_num_drops: usize = total: {
        const all_tiles = model.Board.size * model.Board.size;
        const back_rank = model.Board.size;
        const king_tile = 1;

        break :total all_tiles - back_rank - king_tile;
    };

    try std.testing.expectEqual(expected_num_drops, all_drops.items.len);
}

test "pawn drop cannot checkmate opponent's king" {
    const alloc = std.testing.allocator;

    const player: model.Player = .black;
    const opponent: model.Player = player.swap();

    const invalid_drop: model.Move.Drop = .{
        .piece = .{ .player = player, .sort = .pawn },
        .pos = .{ .x = 4, .y = 5 },
    };

    // The board is set up like so:
    //
    //         [0] [1] [2] [3] [4] [5] [6] [7] [8]
    //     [0]  .   .   .   .   .   .   .   .   .
    //     [1]  .   .   .   .   .   .   .   .   .
    //     [2]  .   .   .   .   .   .   .   .   .
    //     [3]  .   .   .   P   P   P   .   .   .
    //     [4]  .   .   .   P   K   P   .   .   .
    //     [5]  .   .   .   P   .   P   .   .   .
    //     [6]  .   .   .   .   G   .   .   .   .
    //     [7]  .   .   .   .   .   .   .   .   .
    //     [8]  .   .   .   .   .   .   .   .   .
    //
    // Here the gold 'G' belongs to the player, and every other piece
    // belongs to the opponent.
    const board: model.Board = init: {
        var stage = model.Board.empty;

        stage.tiles[3][3] = .{ .player = opponent, .sort = .pawn };
        stage.tiles[3][4] = .{ .player = opponent, .sort = .pawn };
        stage.tiles[3][5] = .{ .player = opponent, .sort = .pawn };
        stage.tiles[4][3] = .{ .player = opponent, .sort = .pawn };
        stage.tiles[4][4] = .{ .player = opponent, .sort = .king };
        stage.tiles[4][5] = .{ .player = opponent, .sort = .pawn };
        stage.tiles[5][3] = .{ .player = opponent, .sort = .pawn };
        stage.tiles[5][5] = .{ .player = opponent, .sort = .pawn };

        stage.tiles[6][4] = .{ .player = player, .sort = .gold };
        stage.getHandPtr(player).put(.pawn, 1);

        break :init stage;
    };

    const all_drops = try pawnDropsFor(.{
        .alloc = alloc,
        .player = player,
        .board = board,
        .test_check = true,
    });
    defer all_drops.deinit();

    var invalid_drop_in_options = false;
    for (all_drops.items) |pos| {
        if (pos.eq(invalid_drop.pos)) {
            invalid_drop_in_options = true;
            break;
        }
    }

    try std.testing.expect(!invalid_drop_in_options);
}
