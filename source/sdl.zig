//! This module provides some simple wrappers around the raw SDL functions.
//! We handle errors in a more idiomatic Zig fashion, and provide "keyword"
//! arguments for functions with long argument lists via the struct trick.
//!
//! Note: if we do get an error from the underlying functions, we always log
//! it with the help of the C functions `SDL_GetError` (to get the details of
//! what happened) and `SDL_LogError` (to do the logging).

const c = @import("c.zig");
const ty = @import("types.zig");
const tile_size = @import("render.zig").tile_size;
const RenderError = @import("render.zig").RenderError;

/// Any kind of error that can happen during initialization of SDL.
pub const InitError = error{
    Initialization,
    CreateWindow,
    CreateRenderer,
};

/// Flags to use for SDL initialization; can be used to enable various
/// subsystems.
pub const sdl_init_flags: u32 =
    c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS;

/// A wrapper around the C function `SDL_Init`.
pub fn sdlInit() InitError!void {
    if (c.SDL_Init(sdl_init_flags) < 0) {
        const msg = "Failed to initialize SDL: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_SYSTEM, msg, c.SDL_GetError());
        return InitError.Initialization;
    }
}

/// This type represents the various configuration options that can be set
/// when creating the game window.
pub const WindowOpts = struct {
    /// Flags to use when creating the main window.
    flags: u32 = 0,
    /// The title of the main window.
    title: [:0]const u8,
    /// The window width.
    width: c_int,
    /// The window height.
    height: c_int,
};

/// Our chosen `WindowOpts` that we use in `createWindow`.
pub const window_opts: WindowOpts = .{
    .title = "Zig Shogi",
    .width = tile_size * ty.Board.size,
    .height = tile_size * ty.Board.size,
};

/// A wrapper around the C function `SDL_CreateWindow`.
pub fn createWindow() InitError!*c.SDL_Window {
    return c.SDL_CreateWindow(
        window_opts.title,
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        window_opts.width,
        window_opts.height,
        window_opts.flags,
    ) orelse {
        const msg = "Failed to create window: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_VIDEO, msg, c.SDL_GetError());
        return InitError.CreateWindow;
    };
}

/// A wrapper around the C function `SDL_CreateRenderer`.
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

/// The arguments to `renderCopy`.
pub const RenderCopyArgs = struct {
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    src_rect: ?*const c.SDL_Rect = null,
    dst_rect: ?*const c.SDL_Rect = null,
    angle: f64 = 0,
    center: ?*const c.SDL_Point = null,
    flip: c.SDL_RendererFlip = c.SDL_FLIP_NONE,
};

/// A wrapper around the C function `SDL_RenderCopyEx`. As that function has a
/// lot of arguments, in order to easily keep track of them we provide a type
/// `RenderCopyArgs` which allows us to give a name to each one, and to provide
/// sensible default arguments where possible.
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
        return RenderError.Copy;
    }
}

/// A wrapper around the C function `IMG_LoadTexture_RW`. If the argument
/// `free_stream` is set to `true`, it will free the `stream` argument during
/// the function call.
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

/// A wrapper around the C function `SDL_RWFromConstMem`.
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

/// A wrapper around the C function `SDL_SetRenderDrawColor`.
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
        return RenderError.SetDrawColour;
    }
}

/// A wrapper around the C function `SDL_RenderClear`. Note: may change the
/// render draw colour.
pub fn renderClear(renderer: *c.SDL_Renderer) RenderError!void {
    const black = ty.Colour{};
    try setRenderDrawColour(renderer, &black);

    if (c.SDL_RenderClear(renderer) < 0) {
        const msg = "Failed to clear renderer: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.Clear;
    }
}

/// A wrapper around the C function `c.SDL_RenderFillRect`. Note: may change
/// the render draw colour.
pub fn renderFillRect(
    renderer: *c.SDL_Renderer,
    colour: *const ty.Colour,
    rect: ?*const c.SDL_Rect,
) RenderError!void {
    try setRenderDrawColour(renderer, colour);

    if (c.SDL_RenderFillRect(renderer, rect) < 0) {
        const msg = "Failed to fill rectangle: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.FillRect;
    }
}
