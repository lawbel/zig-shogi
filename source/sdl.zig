//! This module provides some simple wrappers around the raw SDL functions.
//! We handle errors in a more idiomatic Zig fashion, and provide "keyword"
//! arguments for functions with long argument lists via the struct trick.
//!
//! Note: if we do get an error from the underlying functions, we always log
//! it with the help of the C functions `SDL_GetError` (to get the details of
//! what happened) and `SDL_LogError` (to do the logging).

const c = @import("c.zig");
const pixel = @import("pixel.zig");

/// Any kind of error that these SDL functions can throw.
pub const Error = error{
    CannotLoadTexture,
    CannotReadMemory,
    CannotSetVar,
    RenderError,
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
        shade: ?pixel.Colour = null,
    },
) Error!void {
    const orig: ?pixel.Colour = init: {
        const new = (args.shade) orelse break :init null;
        const old = try getTextureColourMod(args.texture);
        try setTextureColourMod(args.texture, new);
        break :init old;
    };

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
        return error.RenderError;
    }

    // Cannot `defer { ... try ... }`, so put this here rather than above.
    if (orig) |colour| {
        try setTextureColourMod(args.texture, colour);
    }
}

/// Set the RGB colour and alpha values of the given texture's modifier. These
/// values are combined with the texture itself during rendering.
pub fn setTextureColourMod(
    texture: *c.SDL_Texture,
    colour: pixel.Colour,
) Error!void {
    if (c.SDL_SetTextureAlphaMod(texture, colour.alpha) < 0) {
        const msg = "Failed to set texture alpha mod: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotSetVar;
    }

    if (c.SDL_SetTextureColorMod(
        texture,
        colour.red,
        colour.green,
        colour.blue,
    ) < 0) {
        const msg = "Failed to set texture colour mod: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotSetVar;
    }
}

/// Get the RGB colour and alpha values of the given texture's modifier. These
/// values are combined with the texture itself during rendering.
pub fn getTextureColourMod(
    texture: *c.SDL_Texture,
) Error!pixel.Colour {
    var colour: pixel.Colour = undefined;

    if (c.SDL_GetTextureAlphaMod(texture, &colour.alpha) < 0) {
        const msg = "Failed to get texture alpha mod: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotReadMemory;
    }

    if (c.SDL_GetTextureColorMod(
        texture,
        &colour.red,
        &colour.green,
        &colour.blue,
    ) < 0) {
        const msg = "Failed to get texture colour mod: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotReadMemory;
    }

    return colour;
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
) Error!*c.SDL_Texture {
    const texture = c.IMG_LoadTexture_RW(
        args.renderer,
        args.stream,
        if (args.free_stream) 1 else 0,
    ) orelse {
        const msg = "Failed to load texture: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotLoadTexture;
    };

    if (c.SDL_SetTextureBlendMode(texture, args.blend_mode) < 0) {
        const msg = "Failed to set draw blend mode: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotSetVar;
    }

    return texture;
}

/// A wrapper around the C function `SDL_RWFromConstMem`.
pub fn constMemToRw(data: [:0]const u8) Error!*c.SDL_RWops {
    return c.SDL_RWFromConstMem(
        @ptrCast(data),
        @intCast(data.len),
    ) orelse {
        const msg = "Failed to read from const memory: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotReadMemory;
    };
}

/// A wrapper around the C function `SDL_SetRenderDrawColor`.
pub fn setRenderDrawColour(
    renderer: *c.SDL_Renderer,
    colour: pixel.Colour,
) Error!void {
    if (c.SDL_SetRenderDrawColor(
        renderer,
        colour.red,
        colour.green,
        colour.blue,
        colour.alpha,
    ) < 0) {
        const msg = "Failed to set render draw colour: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.CannotSetVar;
    }
}

/// A wrapper around the C function `SDL_RenderClear`. Note: may change the
/// render draw colour.
pub fn renderClear(renderer: *c.SDL_Renderer) Error!void {
    const black = pixel.Colour{};
    try setRenderDrawColour(renderer, black);

    if (c.SDL_RenderClear(renderer) < 0) {
        const msg = "Failed to clear renderer: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.RenderError;
    }
}

/// A wrapper around the C function `c.SDL_RenderFillRect`. Note: may change
/// the render draw colour.
pub fn renderFillRect(
    renderer: *c.SDL_Renderer,
    colour: pixel.Colour,
    rect: ?*const c.SDL_Rect,
) Error!void {
    try setRenderDrawColour(renderer, colour);

    if (c.SDL_RenderFillRect(renderer, rect) < 0) {
        const msg = "Failed to fill rectangle: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.RenderError;
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
) Error!void {
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
        return error.RenderError;
    }
}

/// A wrapper around the C function `c.filledTrigonRGBA` from SDL_gfx.
pub fn renderFillTriangle(
    renderer: *c.SDL_Renderer,
    vertices: [3]Vertex,
    colour: pixel.Colour,
) Error!void {
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
        return error.RenderError;
    }
}

/// Render the given text (which is expected to be UTF-8 encoded) with the
/// given font, style, and colour. The resulting text will be centered about
/// the position of the 'center' argument.
pub fn renderUtf8Text(
    args: struct {
        renderer: *c.SDL_Renderer,
        text: [:0]const u8,
        font: *c.TTF_Font,
        colour: pixel.Colour,
        style: c_int = c.TTF_STYLE_NORMAL,
        center: struct {
            x: c_int,
            y: c_int,
        },
    },
) Error!void {
    const orig_style = c.TTF_GetFontStyle(args.font);
    c.TTF_SetFontStyle(args.font, args.style);
    defer c.TTF_SetFontStyle(args.font, orig_style);

    const colour: c.SDL_Colour = .{
        .r = args.colour.red,
        .g = args.colour.green,
        .b = args.colour.blue,
        .a = args.colour.alpha,
    };
    const surface: *c.SDL_Surface = c.TTF_RenderUTF8_Blended(
        args.font,
        args.text,
        colour,
    ) orelse {
        return error.RenderError;
    };
    defer c.SDL_FreeSurface(surface);

    const texture: *c.SDL_Texture = c.SDL_CreateTextureFromSurface(
        args.renderer,
        surface,
    ) orelse {
        const msg = "Failed to create texture for text: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.RenderError;
    };
    defer c.SDL_DestroyTexture(texture);

    var width: c_int = undefined;
    var height: c_int = undefined;
    if (c.SDL_QueryTexture(texture, null, null, &width, &height) < 0) {
        const msg = "Failed to query rendered text size: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return error.RenderError;
    }

    const top_left_x: c_int = args.center.x - @divFloor(width, 2);
    const top_left_y: c_int = args.center.y - @divFloor(height, 2);
    try renderCopy(.{
        .renderer = args.renderer,
        .texture = texture,
        .dst_rect = &.{
            .x = top_left_x,
            .y = top_left_y,
            .w = width,
            .h = height,
        },
    });
}
