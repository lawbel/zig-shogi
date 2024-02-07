const c = @import("c.zig");
const event = @import("event.zig");
const init = @import("init.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const model = @import("model.zig");
const State = @import("state.zig").State;

/// Target frames per second.
const fps: u32 = 60;

/// The main entry point to the game. We chose to free allocated SDL resources,
/// but they could just as well be intentionally leaked as they will be
/// promptly freed by the OS once the process exits.
pub fn main() !void {
    try init.sdlInit();
    defer init.sdlQuit();

    const window = try init.createWindow(.{ .title = "Zig Shogi" });
    defer c.SDL_DestroyWindow(window);

    const renderer = try init.createRenderer(.{ .window = window });
    defer c.SDL_DestroyRenderer(renderer);

    var state = State.init(.{
        .user = .black,
        .current_player = .black,
        .init_frame = c.SDL_GetTicks(),
    });

    while (true) {
        // Process any events since the last frame.
        switch (event.processEvents(&state)) {
            .quit => break,
            .pass => {},
        }

        // Render the current game state.
        try render.render(renderer, state);

        // Possible sleep for a short while.
        sleepToMatchFps(&state.last_frame);
    }

    render.freeTextures();
}

/// If we used less time than needed to hit our target `fps`, then delay
/// for the left-over time before starting on the next frame.
fn sleepToMatchFps(last_frame: *u32) void {
    // The target duration of one frame, in milliseconds.
    const one_frame: u32 = 1000 / fps;

    // for the left-over time before starting on the next frame.
    const this_frame = c.SDL_GetTicks();
    const time_spent = this_frame - last_frame.*;

    if (time_spent < one_frame) {
        c.SDL_Delay(one_frame - time_spent);
    }

    last_frame.* = this_frame;
}
