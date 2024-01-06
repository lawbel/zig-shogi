const c = @cImport(@cInclude("SDL2/SDL.h"));
const conf = @import("config.zig");

pub fn sdlInit() !void {
    if (c.SDL_Init(conf.sdl_init_flags) < 0) {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_SYSTEM,
            "Failed to initialize SDL: %s",
            c.SDL_GetError(),
        );
        return error.InitializationFailed;
    }
}

pub fn createWindow() !*c.SDL_Window {
    const window = c.SDL_CreateWindow(
        conf.window_title,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        conf.window_width,
        conf.window_height,
        conf.window_flags,
    ) orelse {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_VIDEO,
            "Failed to create window: %s",
            c.SDL_GetError(),
        );
        return error.CreateWindowFailed;
    };

    return window;
}

pub fn createRenderer(window: *c.SDL_Window) !*c.SDL_Renderer {
    const use_any_rendering_driver: c_int = -1;

    const renderer = c.SDL_CreateRenderer(
        window,
        use_any_rendering_driver,
        c.SDL_RENDERER_ACCELERATED,
    ) orelse {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to create renderer: %s",
            c.SDL_GetError(),
        );
        return error.CreateRendererFailed;
    };

    return renderer;
}
