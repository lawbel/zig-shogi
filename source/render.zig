const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_image.h");
});
const conf = @import("config.zig");
const ty = @import("types.zig");

pub const RenderError = error{
    SetRenderDrawColour,
    RenderClear,
    RenderCopy,
    ReadConstMemory,
    LoadTexture,
};

const board_img = @embedFile("../data/board.png");

const background_colour: ty.Colour =
    .{ .red = 0x33, .green = 0x22, .blue = 0x11 };

pub fn render(renderer: *c.SDL_Renderer, board: *ty.Board) RenderError!void {
    _ = board; // autofix

    try setRenderDrawColour(renderer, &background_colour);
    try renderClear(renderer);

    try renderBackground(renderer);
    c.SDL_RenderPresent(renderer);
}

pub fn renderBackground(renderer: *c.SDL_Renderer) RenderError!void {
    const stream = try constMemToRw(board_img);
    defer _ = c.SDL_RWclose(stream);

    const texture = try rwToTexture(renderer, stream, false);
    defer c.SDL_DestroyTexture(texture);

    try renderCopy(renderer, texture, null, null);
}

pub fn renderCopy(
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    src_rect: ?*const c.SDL_Rect,
    dst_rect: ?*const c.SDL_Rect,
) RenderError!void {
    if (c.SDL_RenderCopy(renderer, texture, src_rect, dst_rect) < 0) {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to render copy: %s",
            c.SDL_GetError(),
        );
        return RenderError.RenderCopy;
    }
}

pub fn rwToTexture(
    renderer: *c.SDL_Renderer,
    stream: *c.SDL_RWops,
    free_arg: bool,
) RenderError!*c.SDL_Texture {
    return c.IMG_LoadTexture_RW(
        renderer,
        stream,
        if (free_arg) 1 else 0,
    ) orelse {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to load texture: %s",
            c.SDL_GetError(),
        );
        return RenderError.LoadTexture;
    };
}

pub fn constMemToRw(data: [:0]const u8) RenderError!*c.SDL_RWops {
    return c.SDL_RWFromConstMem(
        @ptrCast(data),
        @intCast(data.len),
    ) orelse {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to read from const memory: %s",
            c.SDL_GetError(),
        );
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
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to set render draw color: %s",
            c.SDL_GetError(),
        );
        return RenderError.SetRenderDrawColour;
    }
}

pub fn renderClear(renderer: *c.SDL_Renderer) RenderError!void {
    if (c.SDL_RenderClear(renderer) < 0) {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to clear renderer: %s",
            c.SDL_GetError(),
        );
        return RenderError.RenderClear;
    }
}
