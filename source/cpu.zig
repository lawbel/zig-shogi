//! This module implements the 'CPU' / 'AI' player logic. That is, it evaluates
//! a position on the board and decides on a move to play.

const model = @import("model.zig");
const mutex = @import("mutex.zig");
const random = @import("random.zig");
const rules = @import("rules.zig");
const State = @import("state.zig").State;
const std = @import("std");
const time = @import("time.zig");

/// Take the `cpu_pending_move` (if any) and update the game state with it.
pub fn applyQueuedMove(state: *State) void {
    const move = state.cpu_pending_move.takeValue() orelse return;
    const is_ok = state.board.applyMove(move);
    std.debug.assert(is_ok);

    state.current_player = state.current_player.swap();
    state.last_move = move;
}

/// The minimum time for the CPU to appear to be thinking about it's move. The
/// UX is strange if they respond instantly, so it's better to insert a small
/// delay if needed. This is actually a range, and each time the actual minimum
/// time used will be randomly chosen from this range.
pub const min_cpu_thinking_time_s = [2]f32{ 0.5, 1.5 };

/// Choose a move for the CPU (may take a not-insignificant amount of time),
/// and then write it to the given `mutex.MutexGuard`.
pub fn queueMove(
    args: struct {
        alloc: std.mem.Allocator,
        player: model.Player,
        board: model.Board,
        dest: *mutex.MutexGuard(model.Move),
    },
) std.mem.Allocator.Error!void {
    const seed = random.randomSeed();
    var prng = std.rand.DefaultPrng.init(seed);
    const rand = prng.random().float(f32);

    const lower = min_cpu_thinking_time_s[0];
    const upper = min_cpu_thinking_time_s[1];
    const time_s = lower + rand * (upper - lower);

    const move = try time.callTakeAtLeast(
        time_s,
        chooseMove,
        .{
            args.alloc,
            args.player,
            args.board,
        },
    );

    args.dest.setValue(move);
}

/// Choose a move to play.
pub fn chooseMove(
    alloc: std.mem.Allocator,
    player: model.Player,
    board: model.Board,
) std.mem.Allocator.Error!model.Move {
    // For now, simply choose any valid move at random.
    return randomMove(alloc, player, board);
}

/// Choose a move at random from all valid moves.
///
/// TODO: handle case where there are no valid moves.
pub fn randomMove(
    alloc: std.mem.Allocator,
    player: model.Player,
    board: model.Board,
) std.mem.Allocator.Error!model.Move {
    var moves = try rules.valid.movesFor(.{
        .alloc = alloc,
        .player = player,
        .board = board,
    });
    defer moves.deinit();

    const basics = moves.basics.map.count();
    const drops = moves.drops.map.count();
    const seed = random.randomSeed();
    var prng = std.rand.DefaultPrng.init(seed);
    const choice = prng.random().intRangeLessThan(usize, 0, basics + drops);

    if (choice < basics) {
        return .{
            .basic = randomMoveBasic(&prng, moves.basics, choice),
        };
    } else {
        return .{
            .drop = randomMoveDrop(&prng, moves.drops, choice - basics),
        };
    }
}

/// Returns a random basic move.
fn randomMoveBasic(
    prng: *std.rand.DefaultPrng,
    basics: rules.types.Basics,
    choice: usize,
) model.Move.Basic {
    var iter = basics.map.iterator();
    while (iter.index < choice) {
        _ = iter.next();
    }

    const entry = iter.next() orelse unreachable;
    const movements = entry.value_ptr.*;
    const index = prng.random().intRangeLessThan(usize, 0, movements.items.len);
    const movement = movements.items[index];
    const promoted = switch (movement.promotion) {
        .cannot_promote => false,
        .can_promote => prng.random().boolean(),
        .must_promote => true,
    };

    return .{
        .from = entry.key_ptr.*,
        .motion = movement.motion,
        .promoted = promoted,
    };
}

/// Returns a random drop.
fn randomMoveDrop(
    prng: *std.rand.DefaultPrng,
    drops: rules.types.Drops,
    choice: usize,
) model.Move.Drop {
    var iter = drops.map.iterator();
    while (iter.index < choice) {
        _ = iter.next();
    }

    const entry = iter.next() orelse unreachable;
    const positions = entry.value_ptr.*;
    const index = prng.random().intRangeLessThan(usize, 0, positions.items.len);
    const pos = positions.items[index];

    return .{
        .pos = pos,
        .piece = entry.key_ptr.*,
    };
}
