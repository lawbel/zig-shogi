const conf = @import("config.zig");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const Error = error{
    InitializationFailed,
    CreateWindowFailed,
    CreateRendererFailed,
};

pub fn sdlInit() Error!void {
    if (sdl.SDL_Init(conf.sdl_init_flags) < 0) {
        sdl.SDL_LogError(
            sdl.SDL_LOG_CATEGORY_SYSTEM,
            "Failed to initialize SDL: %s",
            sdl.SDL_GetError(),
        );
        return Error.InitializationFailed;
    }
}

pub fn createWindow() Error!*sdl.SDL_Window {
    const window = sdl.SDL_CreateWindow(
        conf.window_title,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        sdl.SDL_WINDOWPOS_UNDEFINED,
        conf.window_width,
        conf.window_height,
        conf.window_flags,
    ) orelse {
        sdl.SDL_LogError(
            sdl.SDL_LOG_CATEGORY_VIDEO,
            "Failed to create window: %s",
            sdl.SDL_GetError(),
        );
        return Error.CreateWindowFailed;
    };

    return window;
}

pub fn createRenderer(window: *sdl.SDL_Window) Error!*sdl.SDL_Renderer {
    const use_any_rendering_driver: c_int = -1;

    const renderer = sdl.SDL_CreateRenderer(
        window,
        use_any_rendering_driver,
        sdl.SDL_RENDERER_ACCELERATED,
    ) orelse {
        sdl.SDL_LogError(
            sdl.SDL_LOG_CATEGORY_RENDER,
            "Failed to create renderer: %s",
            sdl.SDL_GetError(),
        );
        return Error.CreateRendererFailed;
    };

    return renderer;
}
