//! This module handles initialization and termination of SDL.

const c = @import("c.zig");
const model = @import("model.zig");
const pixel = @import("pixel.zig");
const render = @import("render.zig");

/// Any kind of error that can happen during initialization of SDL.
pub const Error = error{
    InitFailed,
    CannotCreateWindow,
    CannotCreateRenderer,
    CannotSetVar,
};

/// Flags to use for SDL initialization; can be used to enable various
/// subsystems.
pub const sdl_init_flags: u32 =
    c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER;

/// A wrapper around the C function `SDL_Init`.
pub fn sdlInit() Error!void {
    if (c.SDL_Init(sdl_init_flags) < 0) {
        const msg = "Failed to initialize SDL: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_SYSTEM, msg, c.SDL_GetError());
        return error.InitFailed;
    }
}

/// A wrapper around the C functions `SDL_QuitSubSystem` and `SDL_Quit`.
pub fn sdlQuit() void {
    c.SDL_QuitSubSystem(sdl_init_flags);
    c.SDL_Quit();
}

/// The default window size.
pub const window_size = .{
    .width = pixel.board_padding_horiz + (pixel.tile_size * model.Board.size),
    .height = pixel.board_padding_vert + (pixel.tile_size * model.Board.size),
};

/// The default window position.
pub const window_pos = .{
    .x = c.SDL_WINDOWPOS_UNDEFINED,
    .y = c.SDL_WINDOWPOS_UNDEFINED,
};

/// A wrapper around the C function `SDL_CreateWindow`.
pub fn createWindow(
    args: struct {
        title: [:0]const u8,
        flags: u32 = 0,
        size: struct { width: c_int, height: c_int } = window_size,
        pos: struct { x: c_int, y: c_int } = window_pos,
    },
) Error!*c.SDL_Window {
    return c.SDL_CreateWindow(
        args.title,
        args.pos.x,
        args.pos.y,
        args.size.width,
        args.size.height,
        args.flags,
    ) orelse {
        const msg = "Failed to create window: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_VIDEO, msg, c.SDL_GetError());
        return error.CannotCreateWindow;
    };
}

/// A special value of `rendering_driver` which is interpreted as meaning to
/// use any rendering driver supporting the requested `render_flags`.
pub const use_any_rendering_driver: c_int = -1;

/// A wrapper around the C function `SDL_CreateRenderer`.
pub fn createRenderer(
    args: struct {
        window: *c.SDL_Window,
        blend_mode: c.SDL_BlendMode = render.blend_mode,
        rendering_driver: c_int = use_any_rendering_driver,
        render_flags: u32 = c.SDL_RENDERER_ACCELERATED,
    },
) Error!*c.SDL_Renderer {
    const renderer = c.SDL_CreateRenderer(
        args.window,
        args.rendering_driver,
        args.render_flags,
    ) orelse {
        const msg = "Failed to create renderer: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotCreateRenderer;
    };

    if (c.SDL_SetRenderDrawBlendMode(renderer, args.blend_mode) < 0) {
        const msg = "Failed to set draw blend mode: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotSetVar;
    }

    return renderer;
}
