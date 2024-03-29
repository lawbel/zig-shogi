//! Contains high-level methods for computing all valid moves in a position,
//! or determining if a given move is valid.

const checked = @import("checked.zig");
const dropped = @import("dropped.zig");
const model = @import("../model.zig");
const moved = @import("moved.zig");
const std = @import("std");
const types = @import("types.zig");

/// Errors than can occur while calculating valid movements.
pub const Error = std.mem.Allocator.Error;

/// Returns all valid moves for the given player in the given position.
pub fn movesFor(
    args: struct {
        alloc: std.mem.Allocator,
        player: model.Player,
        board: model.Board,
        test_check: bool = true,
    },
) Error!types.Valid {
    var basics = try movesBasicFor(.{
        .alloc = args.alloc,
        .player = args.player,
        .board = args.board,
        .test_check = args.test_check,
    });
    errdefer basics.deinit();

    const drops = try movesDropFor(.{
        .alloc = args.alloc,
        .player = args.player,
        .board = args.board,
        .test_check = args.test_check,
    });

    return .{
        .basics = basics,
        .drops = drops,
    };
}

/// Returns all valid basic moves (moving an existing piece on the board,
/// excluding possible piece drops) for the given player in the given position.
pub fn movesBasicFor(
    args: struct {
        alloc: std.mem.Allocator,
        player: model.Player,
        board: model.Board,
        test_check: bool = true,
    },
) Error!types.Basics {
    var moves = types.Basics.init(args.alloc);
    errdefer moves.deinit();

    for (args.board.tiles, 0..) |row, y| {
        for (row, 0..) |value, x| {
            const piece = value orelse continue;
            if (!piece.player.eq(args.player)) continue;

            const x_pos: i8 = @intCast(x);
            const y_pos: i8 = @intCast(y);
            const pos: model.BoardPos = .{ .x = x_pos, .y = y_pos };

            const movements = try moved.movementsFrom(.{
                .alloc = args.alloc,
                .from = pos,
                .board = args.board,
                .test_check = args.test_check,
            });
            if (movements.items.len == 0) continue;

            try moves.map.put(pos, movements);
        }
    }

    return moves;
}

/// Returns all valid piece drops for the given player in the given position.
pub fn movesDropFor(
    args: struct {
        alloc: std.mem.Allocator,
        player: model.Player,
        board: model.Board,
        test_check: bool = true,
    },
) Error!types.Drops {
    var moves = types.Drops.init(args.alloc);
    errdefer moves.deinit();

    var test_check = args.test_check;
    if (test_check) {
        test_check = try checked.isInCheck(args.alloc, args.player, args.board);
    }

    const hand = args.board.getHand(args.player);
    inline for (@typeInfo(model.Sort).Enum.fields) |field| {
        const sort: model.Sort = @enumFromInt(field.value);
        const piece: model.Piece = .{ .sort = sort, .player = args.player };
        const count = hand.get(sort) orelse 0;
        if (count > 0) {
            const drops = try dropped.possibleDropsOf(.{
                .alloc = args.alloc,
                .piece = piece,
                .board = args.board,
                .test_check = test_check,
            });
            if (drops.items.len > 0) {
                try moves.map.put(piece, drops);
            }
        }
    }

    return moves;
}

/// Returns whether or not the given move is a valid one, considering the
/// state of the game. Is more efficient than calling `movesFor` and checking
/// all possible options.
pub fn isValid(
    alloc: std.mem.Allocator,
    move: model.Move,
    board: model.Board,
) Error!bool {
    switch (move) {
        .basic => |basic| {
            const moves = try moved.movementsFrom(.{
                .alloc = alloc,
                .from = basic.from,
                .board = board,
            });
            defer moves.deinit();

            for (moves.items) |item| {
                if (basic.motion.eq(item.motion)) {
                    return true;
                }
            }
        },

        .drop => |drop| {
            const hand = board.getHand(drop.piece.player);
            const count_in_hand = hand.get(drop.piece.sort) orelse 0;
            if (count_in_hand == 0) return false;

            const drops = try dropped.possibleDropsOf(.{
                .alloc = alloc,
                .piece = drop.piece,
                .board = board,
            });
            defer drops.deinit();

            for (drops.items) |pos| {
                if (drop.pos.eq(pos)) {
                    return true;
                }
            }
        },
    }

    return false;
}

test "isValid permits moving starting pawns" {
    const alloc = std.testing.allocator;
    const rows = [_]i8{ 2, model.Board.size - 3 };
    const motions = [_]model.Motion{
        .{ .x = 0, .y = 1 },
        .{ .x = 0, .y = -1 },
    };

    for (rows, motions) |row, motion| {
        for (0..model.Board.size) |n| {
            const pos: model.BoardPos = .{ .x = @intCast(n), .y = row };
            const basic = .{ .motion = motion, .from = pos };
            const move = .{ .basic = basic };
            const valid = try isValid(alloc, move, model.Board.init);

            try std.testing.expect(valid);
        }
    }
}

test "isValid forbids moving starting knights" {
    const alloc = std.testing.allocator;
    const max_index = model.Board.size - 1;

    const pos_opts = [2][2]model.BoardPos{
        .{
            .{ .x = 0, .y = 1 },
            .{ .x = 0, .y = max_index - 1 },
        },
        .{
            .{ .x = max_index, .y = 1 },
            .{ .x = max_index, .y = max_index - 1 },
        },
    };
    const motion_opts = [2][2]model.Motion{
        .{ .{ .x = 1, .y = 2 }, .{ .x = -1, .y = 2 } },
        .{ .{ .x = 1, .y = -2 }, .{ .x = -1, .y = -2 } },
    };

    for (pos_opts, motion_opts) |positions, motions| {
        for (positions) |pos| {
            for (motions) |motion| {
                const basic = .{ .motion = motion, .from = pos };
                const move = .{ .basic = basic };
                const valid = try isValid(alloc, move, model.Board.init);
                try std.testing.expect(!valid);
            }
        }
    }
}

test "isValid check example" {
    // Situation is like this:
    //
    // + ー + ー + ー + ー + ー + ー + ー + ー + ー +
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 飛 | 　 | 　 | 　 | 馬 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 玉 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 王 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // + ー + ー + ー + ー + ー + ー + ー + ー + ー +
    //
    // Pieces on the board:
    //
    // * White has the promoted bishop 馬 and their king 王.
    // * Black has the rook 飛 and their king 玉 which is in check.
    //
    // So, in this example, black should be able to capture the promoted
    // bishop or move their king away.

    const alloc = std.testing.allocator;
    const to_move: model.Player = .black;
    const opp: model.Player = to_move.swap();

    const board: model.Board = def: {
        var stage = model.Board.empty;

        stage.tiles[1][1] = .{ .player = to_move, .sort = .rook };
        stage.tiles[1][5] = .{ .player = opp, .sort = .promoted_bishop };
        stage.tiles[2][4] = .{ .player = to_move, .sort = .king };
        stage.tiles[7][4] = .{ .player = opp, .sort = .king };

        break :def stage;
    };

    const expect_valid = [_]model.Move.Basic{
        // Run away with the king.
        .{ .from = .{ .y = 2, .x = 4 }, .motion = .{ .y = 0, .x = -1 } },
        // Capture with the king.
        .{ .from = .{ .y = 2, .x = 4 }, .motion = .{ .y = -1, .x = 1 } },
        // Capture with the rook.
        .{ .from = .{ .y = 1, .x = 1 }, .motion = .{ .y = 0, .x = 4 } },
    };

    for (expect_valid) |basic| {
        const move: model.Move = .{ .basic = basic };
        const valid = try isValid(alloc, move, board);
        try std.testing.expect(valid);
    }
}

test "isValid forbids phase through pieces to block check" {
    // Situation is like this:
    //
    // + ー + ー + ー + ー + ー + ー + ー + ー + ー +
    // | 　 | 　 | 　 | 　 | 玉 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 角 | 　 | 　 |
    // | 　 | 飛 | 　 | 歩 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 | 　 |
    // | 　 | 　 | 　 | 王 | 　 | 　 | 　 | 　 | 　 |
    // + ー + ー + ー + ー + ー + ー + ー + ー + ー +
    //
    // Pieces on the board:
    //
    // * White has a rook 飛, a pawn 歩, and their king 王 currently in check.
    // * Black has the bishop 角 and the king 玉.
    //
    // So, from this position, white needs to get out of check somehow.
    // Blocking with the rook should not possible as the pawn is in the way,
    // and that is what this test is to check for.

    const alloc = std.testing.allocator;
    const to_move: model.Player = .white;
    const opp: model.Player = to_move.swap();

    const board: model.Board = def: {
        var stage = model.Board.empty;

        stage.tiles[0][4] = .{ .player = opp, .sort = .king };
        stage.tiles[5][6] = .{ .player = opp, .sort = .bishop };
        stage.tiles[6][1] = .{ .player = to_move, .sort = .rook };
        stage.tiles[6][3] = .{ .player = to_move, .sort = .pawn };
        stage.tiles[8][3] = .{ .player = to_move, .sort = .king };

        break :def stage;
    };

    const expect_not_valid = [_]model.Move.Basic{
        // Block with the rook.
        .{
            .from = .{ .y = 6, .x = 1 },
            .motion = .{ .y = 0, .x = 4 },
        },
    };

    for (expect_not_valid) |basic| {
        const move: model.Move = .{ .basic = basic };
        const valid = try isValid(alloc, move, board);
        try std.testing.expect(!valid);
    }
}
