//! Handle the events that come in every frame, updating the state as
//! appropriate.

const c = @import("c.zig");
const cpu = @import("cpu.zig");
const model = @import("model.zig");
const render = @import("render.zig");
const rules = @import("rules.zig");
const sdl = @import("sdl.zig");
const State = @import("state.zig").State;
const std = @import("std");

/// A scratch variable used for processing SDL events.
var event: c.SDL_Event = undefined;

/// Whether to exit the main loop or not.
pub const QuitOrPass =
    enum { quit, pass };

/// Any error that can occur while processing events.
pub const Error = std.Thread.SpawnError;

/// Process all events that occured since the last frame. Can throw errors due
/// to a (transitive) call to `std.Thread.spawn`.
pub fn processEvents(
    alloc: std.mem.Allocator,
    state: *State,
) Error!QuitOrPass {
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_MOUSEMOTION => {
                state.mouse.pos.x = event.motion.x;
                state.mouse.pos.y = event.motion.y;
            },

            c.SDL_MOUSEBUTTONDOWN => {
                state.mouse.move_from = state.mouse.pos;
            },

            c.SDL_MOUSEBUTTONUP => {
                defer state.mouse.move_from = null;

                if (event.button.button != c.SDL_BUTTON_LEFT) continue;
                if (!state.current_player.eq(state.user)) continue;

                const moved = try applyUserMove(alloc, state);
                if (moved) try queueCpuMove(alloc, state);
            },

            c.SDL_QUIT => return .quit,

            else => {},
        }
    }

    return .pass;
}

/// Assumes that the user is currently the one whose turn it is. It works out
/// the move the user has inputted based on the mouse movement, and then tries
/// to apply that move to the board. Returns `true` if the move was valid and
/// successfully applied, or `false` otherwise.
fn applyUserMove(alloc: std.mem.Allocator, state: *State) Error!bool {
    const dest = state.mouse.pos.toBoardPos() orelse return false;
    const src_pix = state.mouse.move_from orelse return false;

    if (src_pix.toBoardPos()) |src| {
        return applyUserMoveBasic(.{
            .alloc = alloc,
            .state = state,
            .src = src,
            .dest = dest,
        });
    } else {
        // TODO: handle drops
        return false;
    }
}

/// Apply the given move for the user. Returns `true` if the move was valid and
/// successfully applied, or `false` otherwise.
fn applyUserMoveBasic(
    args: struct {
        alloc: std.mem.Allocator,
        state: *State,
        src: model.BoardPos,
        dest: model.BoardPos,
    },
) Error!bool {
    const piece = args.state.board.get(args.src) orelse return false;
    if (!piece.player.eq(args.state.user)) return false;

    const basic_move: model.Move.Basic = .{
        .from = args.src,
        .motion = .{
            .x = args.dest.x - args.src.x,
            .y = args.dest.y - args.src.y,
        },
    };
    if (basic_move.motion.x == 0 and basic_move.motion.y == 0) return false;

    const move = .{ .basic = basic_move };
    const is_valid =
        try rules.valid.isValid(args.alloc, move, args.state.board);
    if (!is_valid) return false;

    const move_ok = args.state.board.applyMoveBasic(basic_move);
    std.debug.assert(move_ok);
    args.state.last_move = .{ .basic = basic_move };
    args.state.current_player = args.state.current_player.swap();

    return true;
}

/// Spawn (and detach) a `std.Thread` in which the CPU will calculate a move to
/// play, and then push that move onto the `cpu_pending_move` MutexGuard.
fn queueCpuMove(
    alloc: std.mem.Allocator,
    state: *State,
) Error!void {
    const thread_config = .{};
    const thread = try std.Thread.spawn(
        thread_config,
        cpu.queueMove,
        .{
            .{
                .alloc = alloc,
                .player = state.user.swap(),
                .board = state.board,
                .dest = &state.cpu_pending_move,
            },
        },
    );

    thread.detach();
}
