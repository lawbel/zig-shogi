const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const window_title: [:0]const u8 = "Zig Shogi";

pub const window_width: c_int = 800;
pub const window_height: c_int = 600;

pub const window_flags: u32 = 0;

pub const sdl_init_flags: u32 =
    sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_TIMER | sdl.SDL_INIT_EVENTS;
