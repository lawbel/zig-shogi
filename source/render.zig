//! This module contains all the rendering logic for this game.
//!
//! Note on errors: the SDL rendering functions can error for various reasons.
//! Currently we have the setup necessary to recognize and handle those errors
//! however we want, but for now we simply early-return if we encounter any
//! error.

const c = @import("c.zig");
const sdl = @import("sdl.zig");
const ty = @import("types.zig");

/// Any kind of error that can happen during rendering.
pub const RenderError = error{
    SetRenderDrawColour,
    RenderClear,
    RenderCopy,
    ReadConstMemory,
    LoadTexture,
};

/// The raw bytes of the board image.
const board_img = @embedFile("../data/board.png");

/// The raw bytes of the piece image.
const piece_img = @embedFile("../data/piece.png");

/// The size (in pixels) of one tile/square on the game board.
pub const tile_size: c_int = 70;

// As we will use these textures constantly while the program is running, we
// make them global and don't de-allocate them.
var board_texture: ?*c.SDL_Texture = null;
var piece_texture: ?*c.SDL_Texture = null;

/// The main rendering function - it does *all* the rendering each frame, by
/// calling out to helper functions.
pub fn render(
    renderer: *c.SDL_Renderer,
    state: *const ty.State,
) RenderError!void {
    const black = .{ .red = 0, .green = 0, .blue = 0 };

    try sdl.setRenderDrawColour(renderer, &black);
    try sdl.renderClear(renderer);

    try renderBoard(renderer);
    try renderPieces(renderer, state);

    // Take the rendered state and update the window with it.
    c.SDL_RenderPresent(renderer);
}

/// Renders all the pieces on the board.
fn renderPieces(
    renderer: *c.SDL_Renderer,
    state: *const ty.State,
) RenderError!void {
    const texture = piece_texture orelse init: {
        const stream = try sdl.constMemToRw(piece_img);
        // This call to rwToTexture frees the `stream`.
        const tex = try sdl.rwToTexture(renderer, stream, true);
        piece_texture = tex;
        break :init tex;
    };

    var move_player: ?ty.Player = null;
    var move_from: ?ty.BoardPos =
        if (state.mouse.move.from) |pos| pos.toBoardPos() else null;

    for (state.board.squares, 0..) |row, y| {
        for (row, 0..) |val, x| if (val) |piece| render: {
            if (move_from) |pos| if (x == pos.x and y == pos.y) {
                move_player = piece.player;
                break :render;
            };

            try sdl.renderCopy(.{
                .renderer = renderer,
                .texture = texture,
                .dst_rect = &.{
                    .x = tile_size * @as(c_int, @intCast(x)),
                    .y = tile_size * @as(c_int, @intCast(y)),
                    .w = tile_size,
                    .h = tile_size,
                },
                .angle = switch (piece.player) {
                    .white => 0,
                    .black => 180,
                },
            });
        };
    }

    // We need to render any piece the player may be moving last, so it
    // appears on top of everything else.
    if (move_player) |player| if (state.mouse.move.from) |from| {
        const offset = from.offsetFromGrid();
        try sdl.renderCopy(.{
            .renderer = renderer,
            .texture = texture,
            .dst_rect = &.{
                .x = state.mouse.pos.x - offset.x,
                .y = state.mouse.pos.y - offset.y,
                .w = tile_size,
                .h = tile_size,
            },
            .angle = switch (player) {
                .white => 0,
                .black => 180,
            },
        });
    };
}

/// Renders the game board.
fn renderBoard(renderer: *c.SDL_Renderer) RenderError!void {
    const texture = board_texture orelse init: {
        const stream = try sdl.constMemToRw(board_img);
        // This call to rwToTexture frees the `stream`.
        const tex = try sdl.rwToTexture(renderer, stream, true);
        board_texture = tex;
        break :init tex;
    };

    try sdl.renderCopy(.{ .renderer = renderer, .texture = texture });
}
