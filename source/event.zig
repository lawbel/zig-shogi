//! Handle the events that come in every frame, updating the state as
//! appropriate.

const c = @import("c.zig");
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

/// Process all events that occured since the last frame.
pub fn processEvents(state: *State) QuitOrPass {
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_MOUSEMOTION => {
                state.mouse.pos.x = event.motion.x;
                state.mouse.pos.y = event.motion.y;
            },

            c.SDL_MOUSEBUTTONDOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    state.mouse.move.from = state.mouse.pos;
                }
            },

            c.SDL_MOUSEBUTTONUP => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    leftClickRelease(state);
                }
            },

            c.SDL_QUIT => return .quit,

            else => {},
        }
    }

    return .pass;
}

/// Process the left-mouse button being released.
fn leftClickRelease(state: *State) void {
    defer state.mouse.move.from = null;

    // If the user is not the current player, then we ignore their move input.
    if (state.current.not_eq(state.user)) {
        return;
    }

    const dest = model.BoardPos.fromPixelPos(state.mouse.pos);
    const src_pix = (state.mouse.move.from) orelse return;

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
        processMove(state, move);
    }

    state.current.swap();
}

/// Process the given `model.Move` by updating the state as appropriate.
fn processMove(
    state: *State,
    move: model.Move,
) void {
    const src_piece = state.board.get(move.pos);
    const dest = move.pos.applyMotion(move.motion) orelse return;
    const dest_piece = state.board.get(dest);

    // Update the board.
    state.board.set(move.pos, null);
    state.board.set(dest, src_piece);

    // Update the last move.
    state.last = move;

    // Add the captured piece (if any) to the players hand.
    const piece = dest_piece orelse return;
    const sort = piece.sort.demote();

    var hand: *std.EnumMap(model.Sort, i8) = undefined;
    if (state.user == .white) {
        hand = &state.board.hand.white;
    } else {
        hand = &state.board.hand.black;
    }

    if (hand.getPtr(sort)) |count| {
        count.* += 1;
    }
}
