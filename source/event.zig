//! Handle the events that come in every frame, updating the state as
//! appropriate.

const c = @import("c.zig");
const cpu = @import("cpu.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const std = @import("std");
const model = @import("model.zig");
const rules = @import("rules.zig");
const State = @import("state.zig").State;

/// A scratch variable used for processing SDL events.
var event: c.SDL_Event = undefined;

/// Whether to exit the main loop or not.
pub const QuitOrPass =
    enum { quit, pass };

pub const EventError = error{
    EventThread,
};

/// Process all events that occured since the last frame. Can throw errors due
/// to a (transitive) call to `std.Thread.spawn`.
pub fn processEvents(state: *State) EventError!QuitOrPass {
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

                const moved = try applyUserMove(state);
                if (moved) try queueCpuMove(state);
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
fn applyUserMove(state: *State) EventError!bool {
    const dest = state.mouse.pos.toBoardPos();
    const src_pix = state.mouse.move_from orelse return false;
    const src = src_pix.toBoardPos();
    const piece = state.board.get(src) orelse return false;
    const move: model.Move = .{
        .pos = src,
        .motion = .{
            .x = dest.x - src.x,
            .y = dest.y - src.y,
        },
    };

    if (piece.player.not_eq(state.user)) return false;
    if (move.motion.x == 0 and move.motion.y == 0) return false;
    if (!rules.isValid(move, state.board)) return false;

    state.board.applyMove(move);
    state.last_move = move;
    state.current_player = state.current_player.swap();

    return true;
}

/// Spawn (and detach) a `std.Thread` in which the CPU will calculate a move to
/// play, and then push that move onto the `cpu_pending_move` MutexGuard.
fn queueCpuMove(state: *State) EventError!void {
    const thread_config = .{};

    const thread = std.Thread.spawn(
        thread_config,
        cpu.queueMove,
        .{
            state.user.swap(),
            state.board,
            &state.cpu_pending_move,
        },
    ) catch {
        return error.EventThread;
    };

    thread.detach();
}
