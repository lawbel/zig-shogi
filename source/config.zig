const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
});

pub const window_title: [:0]const u8 = "Zig Shogi";

pub const window_width: c_int = 600;
pub const window_height: c_int = 600;

pub const window_flags: u32 = 0;

pub const sdl_init_flags: u32 =
    c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS;

pub const fps: u32 = 60;
