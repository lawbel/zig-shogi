const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
});
const conf = @import("config.zig");
const init = @import("init.zig");
const render = @import("render.zig");
const ty = @import("types.zig");

pub fn main() !void {
    try init.sdlInit();
    defer c.SDL_Quit();

    const window = try init.createWindow();
    defer c.SDL_DestroyWindow(window);

    const renderer = try init.createRenderer(window);
    defer c.SDL_DestroyRenderer(renderer);

    var board = ty.Board.init;
    var event: c.SDL_Event = undefined;

    main_loop: while (true) {
        // Process all events that occured since the last frame.
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => break :main_loop,
                else => {},
            }
        }

        try render.render(renderer, &board);

        const one_s_in_ms: u32 = 1000;
        c.SDL_Delay(one_s_in_ms / conf.fps);
    }
}
