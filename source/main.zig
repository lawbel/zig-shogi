const c = @import("c.zig");
const cpu = @import("cpu.zig");
const event = @import("event.zig");
const init = @import("init.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const time = @import("time.zig");
const model = @import("model.zig");
const State = @import("state.zig").State;

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
        // Process any events since the last frame. May spawn a thread for the
        // CPU to calculate its move.
        const result = try event.processEvents(&state);
        switch (result) {
            .quit => break,
            .pass => {},
        }

        // If the CPU has decided on a move, update the game state with it.
        cpu.applyQueuedMove(&state);

        // Render the current game state.
        try render.render(renderer, state);

        // Possible sleep for a short while.
        time.sleepToMatchFps(&state.last_frame);
    }

    render.freeTextures();
}
