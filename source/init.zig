const c = @import("c.zig");
const conf = @import("config.zig");

pub const InitError = error{
    Initialization,
    CreateWindow,
    CreateRenderer,
};

pub fn sdlInit() InitError!void {
    if (c.SDL_Init(conf.sdl_init_flags) < 0) {
        const msg = "Failed to initialize SDL: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_SYSTEM, msg, c.SDL_GetError());
        return InitError.Initialization;
    }
}

pub fn createWindow() InitError!*c.SDL_Window {
    return c.SDL_CreateWindow(
        conf.window_title,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        conf.window_width,
        conf.window_height,
        conf.window_flags,
    ) orelse {
        const msg = "Failed to create window: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_VIDEO, msg, c.SDL_GetError());
        return InitError.CreateWindow;
    };
}

pub fn createRenderer(window: *c.SDL_Window) InitError!*c.SDL_Renderer {
    const use_any_rendering_driver: c_int = -1;

    return c.SDL_CreateRenderer(
        window,
        use_any_rendering_driver,
        c.SDL_RENDERER_ACCELERATED,
    ) orelse {
        const msg = "Failed to create renderer: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return InitError.CreateRenderer;
    };
}
