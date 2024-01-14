//! This module provides some simple wrappers around the raw SDL functions.
//! We handle errors in a more idiomatic Zig fashion, and provide "keyword"
//! arguments for functions with long argument lists via the struct trick.
const c = @import("c.zig");
const conf = @import("config.zig");
const render = @import("render.zig");
const ty = @import("types.zig");

// Declared in render.zig but mostly used here. Perhaps it would be better to
// change it to declare it here instead?
const RenderError = render.RenderError;

/// Any kind of error that can happen during initialization of SDL.
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

pub const RenderCopyArgs = struct {
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    src_rect: ?*const c.SDL_Rect = null,
    dst_rect: ?*const c.SDL_Rect = null,
    angle: f64 = 0,
    center: ?*const c.SDL_Point = null,
    flip: c.SDL_RendererFlip = c.SDL_FLIP_NONE,
};

pub fn renderCopy(args: RenderCopyArgs) RenderError!void {
    if (c.SDL_RenderCopyEx(
        args.renderer,
        args.texture,
        args.src_rect,
        args.dst_rect,
        args.angle,
        args.center,
        args.flip,
    ) < 0) {
        const msg = "Failed to render copy: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.RenderCopy;
    }
}

pub fn rwToTexture(
    renderer: *c.SDL_Renderer,
    stream: *c.SDL_RWops,
    free_stream: bool,
) RenderError!*c.SDL_Texture {
    return c.IMG_LoadTexture_RW(
        renderer,
        stream,
        if (free_stream) 1 else 0,
    ) orelse {
        const msg = "Failed to load texture: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.LoadTexture;
    };
}

pub fn constMemToRw(data: [:0]const u8) RenderError!*c.SDL_RWops {
    return c.SDL_RWFromConstMem(
        @ptrCast(data),
        @intCast(data.len),
    ) orelse {
        const msg = "Failed to read from const memory: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.ReadConstMemory;
    };
}

pub fn setRenderDrawColour(
    renderer: *c.SDL_Renderer,
    colour: *const ty.Colour,
) RenderError!void {
    if (c.SDL_SetRenderDrawColor(
        renderer,
        colour.red,
        colour.green,
        colour.blue,
        colour.alpha,
    ) < 0) {
        const msg = "Failed to set render draw color: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.SetRenderDrawColour;
    }
}

pub fn renderClear(renderer: *c.SDL_Renderer) RenderError!void {
    if (c.SDL_RenderClear(renderer) < 0) {
        const msg = "Failed to clear renderer: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.RenderClear;
    }
}
