const c = @import("c.zig");
const conf = @import("config.zig");
const sdl = @import("sdl.zig");
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

// As we will use these textures constantly while the program is running, we
// make them global and don't de-allocate them.
var board_texture: ?*c.SDL_Texture = null;
var piece_texture: ?*c.SDL_Texture = null;

pub fn render(renderer: *c.SDL_Renderer, board: *ty.Board) RenderError!void {
    const black = .{ .red = 0, .green = 0, .blue = 0 };

    try sdl.setRenderDrawColour(renderer, &black);
    try sdl.renderClear(renderer);

    try renderBoard(renderer);
    try renderPieces(renderer, board);

    c.SDL_RenderPresent(renderer);
}

fn renderPieces(renderer: *c.SDL_Renderer, board: *ty.Board) RenderError!void {
    const texture = piece_texture orelse init: {
        const stream = try sdl.constMemToRw(piece_img);
        const tex = try sdl.rwToTexture(renderer, stream, true);
        piece_texture = tex;
        break :init tex;
    };

    for (board.squares, 0..) |row, y| {
        for (row, 0..) |val, x| {
            if (val) |piece| {
                const dest: c.SDL_Rect = .{
                    .x = conf.tile_size * @as(c_int, @intCast(x)),
                    .y = conf.tile_size * @as(c_int, @intCast(y)),
                    .w = conf.tile_size,
                    .h = conf.tile_size,
                };
                try sdl.renderCopy(.{
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
    const texture = board_texture orelse init: {
        const stream = try sdl.constMemToRw(board_img);
        const tex = try sdl.rwToTexture(renderer, stream, true);
        board_texture = tex;
        break :init tex;
    };

    try sdl.renderCopy(.{ .renderer = renderer, .texture = texture });
}
