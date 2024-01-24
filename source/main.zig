const c = @import("c.zig");
const event = @import("event.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const ty = @import("types.zig");

const init_state: ty.State = .{
    .board = ty.Board.init,
    .player = .white,
    .mouse = .{
        .pos = .{ .x = 0, .y = 0 },
        .move = .{ .from = null },
    },
};

/// The target duration of one frame, in milliseconds.
const one_frame: u32 = 1000 / render.fps;

pub fn main() !void {
    try sdl.sdlInit();
    defer c.SDL_Quit();

    const window = try sdl.createWindow();
    defer c.SDL_DestroyWindow(window);

    const renderer = try sdl.createRenderer(window, render.blend_mode);
    defer c.SDL_DestroyRenderer(renderer);

    var state: ty.State = init_state;
    var last_frame: u32 = c.SDL_GetTicks();

    main_loop: while (true) {
        // Process any events since the last frame.
        switch (event.processEvents(&state)) {
            .exit => break :main_loop,
            .pass => {},
        }

        // Render the current game state.
        try render.render(renderer, &state);

        // If we used less time than needed to hit our target `fps`, then delay
        // for the left-over time before starting on the next frame.
        const this_frame = c.SDL_GetTicks();
        const time_spent = this_frame - last_frame;

        if (time_spent < one_frame) {
            c.SDL_Delay(one_frame - time_spent);
        }

        last_frame = this_frame;
    }
}
