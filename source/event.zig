//! Handle the events that come in every frame, updating the state as
//! appropriate.

const c = @import("c.zig");
const render = @import("render.zig");
const rules = @import("rules.zig");
const sdl = @import("sdl.zig");
const ty = @import("types.zig");

/// A scratch variable used for processing SDL events.
var event: c.SDL_Event = undefined;

/// Whether to exit the main loop or not.
pub const MaybeExit =
    enum { exit, pass };

/// Process all events that occured since the last frame.
pub fn processEvents(state: *ty.State) MaybeExit {
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
                if (event.button.button == c.SDL_BUTTON_LEFT) set: {
                    const dest = state.mouse.pos.toBoardPos();
                    const src_pix = (state.mouse.move.from) orelse {
                        break :set;
                    };
                    const src = src_pix.toBoardPos();
                    const move = rules.Move{
                        .x = dest.x - src.x,
                        .y = dest.y - src.y,
                    };

                    if (move.isValid(src, state.board)) {
                        const src_piece = state.board.get(src);
                        state.board.set(src, null);
                        state.board.set(dest, src_piece);
                    }

                    state.mouse.move.from = null;
                }
            },

            c.SDL_QUIT => return .exit,

            else => {},
        }
    }

    return .pass;
}
