const c = @import("c.zig");
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

    const renderer = try sdl.createRenderer(window);
    defer c.SDL_DestroyRenderer(renderer);

    var event: c.SDL_Event = undefined;
    var state: ty.State = .{
        .board = ty.Board.init,
        .mouse = .{
            .pos = .{ .x = 0, .y = 0 },
            .move = .{ .from = null },
        },
    };

    main_loop: while (true) {
        // Process all events that occured since the last frame.
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
                c.SDL_QUIT => break :main_loop,
                else => {},
            }
        }

        // Render the current game state.
        try render.render(renderer, &state);

        const one_s_in_ms: u32 = 1000;
        c.SDL_Delay(one_s_in_ms / fps);
    }
}
