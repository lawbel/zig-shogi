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
const piece_img = @embedFile("../data/piece.png");

pub fn render(renderer: *c.SDL_Renderer, board: *ty.Board) RenderError!void {
    const black: ty.Colour = .{ .red = 0, .green = 0, .blue = 0 };

    try setRenderDrawColour(renderer, &black);
    try renderClear(renderer);

    try renderBoard(renderer);
    try renderPieces(renderer, board);

    c.SDL_RenderPresent(renderer);
}

fn renderPieces(renderer: *c.SDL_Renderer, board: *ty.Board) RenderError!void {
    const stream = try constMemToRw(piece_img);
    defer _ = c.SDL_RWclose(stream);

    const texture = try rwToTexture(renderer, stream, false);
    defer c.SDL_DestroyTexture(texture);

    for (board.squares, 0..) |row, y| {
        for (row, 0..) |val, x| {
            if (val) |piece| {
                const dest: c.SDL_Rect = .{
                    .x = conf.tile_size * @as(c_int, @intCast(x)),
                    .y = conf.tile_size * @as(c_int, @intCast(y)),
                    .w = conf.tile_size,
                    .h = conf.tile_size,
                };
                try renderCopy(.{
                    .renderer = renderer,
                    .texture = texture,
                    .dst_rect = &dest,
                    .angle = switch (piece.player) {
                        .white => 0,
                        .black => 180,
                    },
                });
            }
        }
    }
}

fn renderBoard(renderer: *c.SDL_Renderer) RenderError!void {
    const stream = try constMemToRw(board_img);
    defer _ = c.SDL_RWclose(stream);

    const texture = try rwToTexture(renderer, stream, false);
    defer c.SDL_DestroyTexture(texture);

    try renderCopy(.{ .renderer = renderer, .texture = texture });
}

const RenderCopyArgs = struct {
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    src_rect: ?*const c.SDL_Rect = null,
    dst_rect: ?*const c.SDL_Rect = null,
    angle: f64 = 0,
    center: ?*const c.SDL_Point = null,
    flip: c.SDL_RendererFlip = c.SDL_FLIP_NONE,
};

fn renderCopy(args: RenderCopyArgs) RenderError!void {
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

fn rwToTexture(
    renderer: *c.SDL_Renderer,
    stream: *c.SDL_RWops,
    free_arg: bool,
) RenderError!*c.SDL_Texture {
    return c.IMG_LoadTexture_RW(
        renderer,
        stream,
        if (free_arg) 1 else 0,
    ) orelse {
        const msg = "Failed to load texture: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.LoadTexture;
    };
}

fn constMemToRw(data: [:0]const u8) RenderError!*c.SDL_RWops {
    return c.SDL_RWFromConstMem(
        @ptrCast(data),
        @intCast(data.len),
    ) orelse {
        const msg = "Failed to read from const memory: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.ReadConstMemory;
    };
}

fn setRenderDrawColour(
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

fn renderClear(renderer: *c.SDL_Renderer) RenderError!void {
    if (c.SDL_RenderClear(renderer) < 0) {
        const msg = "Failed to clear renderer: %s";
        c.SDL_LogError(c.SDL_LOG_CATEGORY_RENDER, msg, c.SDL_GetError());
        return RenderError.RenderClear;
    }
}
