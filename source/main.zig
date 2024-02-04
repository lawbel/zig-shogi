const c = @import("c.zig");
const event = @import("event.zig");
const init = @import("init.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const ty = @import("types.zig");

/// The target duration of one frame, in milliseconds.
const one_frame: u32 = 1000 / render.fps;

/// The main entry point to the game.
pub fn main() !void {
    try init.sdlInit();
    defer init.sdlQuit();

    const window = try init.createWindow(.{ .title = "Zig Shogi" });
    defer c.SDL_DestroyWindow(window);

    const renderer = try init.createRenderer(.{ .window = window });
    defer c.SDL_DestroyRenderer(renderer);

    var last_frame: u32 = c.SDL_GetTicks();
    var state: ty.State = ty.State.init(.{
        .user = .black,
        .current = .black,
    });

    while (true) {
        // Process any events since the last frame.
        switch (event.processEvents(&state)) {
            .exit => break,
            .pass => {},
        }

        // Render the current game state.
        try render.render(renderer, state);

        // If we used less time than needed to hit our target `fps`, then delay
        // for the left-over time before starting on the next frame.
        const this_frame = c.SDL_GetTicks();
        const time_spent = this_frame - last_frame;

        if (time_spent < one_frame) {
            c.SDL_Delay(one_frame - time_spent);
        }

        last_frame = this_frame;
    }

    render.freeTextures();
}
