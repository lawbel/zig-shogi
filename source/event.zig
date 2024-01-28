const c = @import("c.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const ty = @import("types.zig");

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
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    state.mouse.move.from = null;
                    // state.mouse.move.to = state.mouse.pos;
                    // move_piece();
                }
            },
            c.SDL_QUIT => return .exit,
            else => {},
        }
    }

    return .pass;
}
