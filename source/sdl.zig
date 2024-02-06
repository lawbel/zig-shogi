//! This module provides some simple wrappers around the raw SDL functions.
//! We handle errors in a more idiomatic Zig fashion, and provide "keyword"
//! arguments for functions with long argument lists via the struct trick.
//!
//! Note: if we do get an error from the underlying functions, we always log
//! it with the help of the C functions `SDL_GetError` (to get the details of
//! what happened) and `SDL_LogError` (to do the logging).

const c = @import("c.zig");
const pixel = @import("pixel.zig");
const model = @import("model.zig");

pub const SdlError = error{
    SdlCopy,
    SdlLoadTexture,
    SdlSetDrawBlendMode,
    SdlReadConstMemory,
    SdlSetDrawColour,
    SdlClear,
    SdlFillRect,
    SdlFillCircle,
    SdlFillTriangle,
};

/// A wrapper around the C function `SDL_RenderCopyEx`. As that function has a
/// lot of arguments, in order to easily keep track of them we take them in as
/// a struct which allows us to give a name to each one, and to provide
/// sensible default arguments where possible.
pub fn renderCopy(
    args: struct {
        renderer: *c.SDL_Renderer,
        texture: *c.SDL_Texture,
        src_rect: ?*const c.SDL_Rect = null,
        dst_rect: ?*const c.SDL_Rect = null,
        angle: f64 = 0,
        center: ?*const c.SDL_Point = null,
        flip: c.SDL_RendererFlip = c.SDL_FLIP_NONE,
    },
) SdlError!void {
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
        return error.SdlCopy;
    }
}

/// A wrapper around the C function `IMG_LoadTexture_RW`. If the argument
/// `free_stream` is set to `true`, it will free the `stream` argument during
/// the function call.
pub fn rwToTexture(
    args: struct {
        renderer: *c.SDL_Renderer,
        stream: *c.SDL_RWops,
        free_stream: bool,
        blend_mode: c.SDL_BlendMode,
    },
) SdlError!*c.SDL_Texture {
    const texture = c.IMG_LoadTexture_RW(
        args.renderer,
        args.stream,
        if (args.free_stream) 1 else 0,
    ) orelse {
        const msg = "Failed to load texture: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.SdlLoadTexture;
    };

    if (c.SDL_SetTextureBlendMode(texture, args.blend_mode) < 0) {
        const msg = "Failed to set draw blend mode: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.SdlSetDrawBlendMode;
    }

    return texture;
}

/// A wrapper around the C function `SDL_RWFromConstMem`.
pub fn constMemToRw(data: [:0]const u8) SdlError!*c.SDL_RWops {
    return c.SDL_RWFromConstMem(
        @ptrCast(data),
        @intCast(data.len),
    ) orelse {
        const msg = "Failed to read from const memory: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.SdlReadConstMemory;
    };
}

/// A wrapper around the C function `SDL_SetRenderDrawColor`.
pub fn setRenderDrawColour(
    renderer: *c.SDL_Renderer,
    colour: pixel.Colour,
) SdlError!void {
    if (c.SDL_SetRenderDrawColor(
        renderer,
        colour.red,
        colour.green,
        colour.blue,
        colour.alpha,
    ) < 0) {
        const msg = "Failed to set render draw color: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.SdlSetDrawColour;
    }
}

/// A wrapper around the C function `SDL_RenderClear`. Note: may change the
/// render draw colour.
pub fn renderClear(renderer: *c.SDL_Renderer) SdlError!void {
    const black = pixel.Colour{};
    try setRenderDrawColour(renderer, black);

    if (c.SDL_RenderClear(renderer) < 0) {
        const msg = "Failed to clear renderer: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.SdlClear;
    }
}

/// A wrapper around the C function `c.SDL_RenderFillRect`. Note: may change
/// the render draw colour.
pub fn renderFillRect(
    renderer: *c.SDL_Renderer,
    colour: pixel.Colour,
    rect: ?*const c.SDL_Rect,
) SdlError!void {
    try setRenderDrawColour(renderer, colour);

    if (c.SDL_RenderFillRect(renderer, rect) < 0) {
        const msg = "Failed to fill rectangle: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.SdlFillRect;
    }
}

/// A pixel position on the screen. This is conceptually the same as
/// `model.PixelPos`, but uses `i16` instead of `i32` as some SDL functions
/// require that integer type instead.
pub const Vertex = struct {
    x: i16,
    y: i16,
};

/// A wrapper around the C function `c.filledCircleRGBA` from SDL_gfx.
pub fn renderFillCircle(
    args: struct {
        renderer: *c.SDL_Renderer,
        colour: pixel.Colour,
        centre: Vertex,
        radius: i16,
    },
) SdlError!void {
    if (c.filledCircleRGBA(
        // The renderer.
        args.renderer,
        // Coordinates.
        args.centre.x,
        args.centre.y,
        args.radius,
        // Colour values.
        args.colour.red,
        args.colour.green,
        args.colour.blue,
        args.colour.alpha,
    ) < 0) {
        const msg = "Failed to fill circle";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg);
        return error.SdlFillCircle;
    }
}

/// A wrapper around the C function `c.filledTrigonRGBA` from SDL_gfx.
pub fn renderFillTriangle(
    renderer: *c.SDL_Renderer,
    vertices: [3]Vertex,
    colour: pixel.Colour,
) SdlError!void {
    if (c.filledTrigonRGBA(
        // The renderer.
        renderer,
        // First vertex.
        vertices[0].x,
        vertices[0].y,
        // Second vertex.
        vertices[1].x,
        vertices[1].y,
        // Third vertex.
        vertices[2].x,
        vertices[2].y,
        // Colour values.
        colour.red,
        colour.green,
        colour.blue,
        colour.alpha,
    ) < 0) {
        const msg = "Failed to fill triangle";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg);
        return error.SdlFillTriangle;
    }
}
