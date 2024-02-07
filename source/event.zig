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
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    state.mouse.move_from = state.mouse.pos;
                }
            },

            c.SDL_MOUSEBUTTONUP => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    try leftClickRelease(state);
                }
            },

            c.SDL_QUIT => return .quit,

            else => {},
        }
    }

    return .pass;
}

/// Process the left-mouse button being released.
fn leftClickRelease(state: *State) EventError!void {
    try applyUserMove(state);
    try queueCpuMove(state);
}

fn applyUserMove(state: *State) EventError!void {
    defer state.mouse.move_from = null;

    // If the user is not the current player, then we ignore their move input.
    if (state.current_player.not_eq(state.user)) {
        return;
    }

    const dest = model.BoardPos.fromPixelPos(state.mouse.pos);
    const src_pix = (state.mouse.move_from) orelse return;

    const src = model.BoardPos.fromPixelPos(src_pix);
    const move: model.Move = .{
        .pos = src,
        .motion = .{
            .x = dest.x - src.x,
            .y = dest.y - src.y,
        },
    };

    var user_owns_piece = false;
    if (state.board.get(src)) |piece| {
        user_owns_piece = piece.player.eq(state.user);
    }

    if (rules.isValid(move, state.board) and user_owns_piece) {
        state.board.applyMove(move);
        state.last_move = move;
    }

    state.current_player = state.current_player.swap();
}

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
