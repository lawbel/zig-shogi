//! This module implements the 'CPU' / 'AI' player logic. That is, it evaluates
//! a position on the board and decides on a move to play.

const rules = @import("rules.zig");
const std = @import("std");
const model = @import("model.zig");
const mutex = @import("mutex.zig");
const state = @import("state.zig");
const random = @import("random.zig");

/// An array with enough space to accomodate all possible `model.Move`s from a
/// given position.
const Moves = std.BoundedArray(model.Move, max_pieces * rules.max_moves);

/// An upper bound on the maximum number of pieces a player could have at a
/// time.
pub const max_pieces: usize = (model.Board.size * 4) + 4;

/// Take the `cpu_pending_move` (if any) and update the game state with it.
pub fn applyQueuedMove(cur_state: *state.State) void {
    const move = cur_state.cpu_pending_move.takeValue() orelse return;

    cur_state.board.applyMove(move);
    cur_state.current_player = cur_state.current_player.swap();
    cur_state.last_move = move;
}

/// Choose a move for the CPU (may take a not-insignificant amount of time),
/// and then write it to the given `mutex.MutexGuard`.
pub fn queueMove(
    player: model.Player,
    board: model.Board,
    dest: *mutex.MutexGuard(model.Move),
) void {
    const move = chooseMove(player, board);
    dest.setValue(move);
}

/// Choose a move to play.
pub fn chooseMove(player: model.Player, board: model.Board) model.Move {
    // For now, simply choose any valid move at random.
    return randomMove(player, board);
}

/// Choose a move at random from all valid moves. TODO: handle drops.
pub fn randomMove(player: model.Player, board: model.Board) model.Move {
    var moves = Moves.init(0) catch unreachable;
    const seed = random.randomSeed();

    for (board.tiles, 0..model.Board.size) |row, y| {
        for (row, 0..model.Board.size) |tile, x| {
            const piece = tile orelse continue;
            if (piece.player.not_eq(player)) continue;

            const pos: model.BoardPos = .{
                .x = @intCast(x),
                .y = @intCast(y),
            };
            const motions = rules.validMotions(pos, board).slice();

            for (motions) |motion| {
                const move = .{ .pos = pos, .motion = motion };
                moves.appendAssumeCapacity(move);
            }
        }
    }

    var prng = std.rand.DefaultPrng.init(seed);
    const choice = prng.random().intRangeAtMost(usize, 0, moves.len);

    return moves.get(choice);
}
