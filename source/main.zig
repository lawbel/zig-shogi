const c = @import("c.zig");
const event = @import("event.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const ty = @import("types.zig");

/// Desired frames per second.
pub const fps: u32 = 60;

pub fn main() !void {
    try sdl.sdlInit();
    defer c.SDL_Quit();

    const window = try sdl.createWindow();
    defer c.SDL_DestroyWindow(window);

    const renderer = try sdl.createRenderer(window, render.blend_mode);
    defer c.SDL_DestroyRenderer(renderer);

    var state: ty.State = .{
        .board = ty.Board.init,
        .mouse = .{
            .pos = .{ .x = 0, .y = 0 },
            .move = .{ .from = null },
        },
        .player = .white,
    };

    main_loop: while (true) {
        // Process any events since the last frame.
        switch (event.processEvents(&state)) {
            .exit => break :main_loop,
            .pass => {},
        }

        // Render the current game state.
        try render.render(renderer, &state);

        const one_s_in_ms: u32 = 1000;
        c.SDL_Delay(one_s_in_ms / fps);
    }
}
