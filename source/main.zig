const init = @import("init.zig");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub fn main() !void {
    try init.sdlInit();
    defer sdl.SDL_Quit();

    const window = try init.createWindow();
    defer sdl.SDL_DestroyWindow(window);

    const renderer = try init.createRenderer(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    sdl.SDL_Delay(1_000);
}
