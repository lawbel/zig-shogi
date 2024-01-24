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
    RenderSetDrawColour,
    RenderSetDrawBlendMode,
    RenderClear,
    RenderCopy,
    RenderFillRect,
    RenderReadConstMemory,
    RenderLoadTexture,
};

/// The blending mode to use for all rendering.
pub const blend_mode: c_int = c.SDL_BLENDMODE_BLEND;

/// The size (in pixels) of one tile/square on the game board.
pub const tile_size: c_int = 70;

/// The board SDL texture. As we will use this textures constantly while the
/// program is running, we make it a global for easy re-use.
var board_texture: ?*c.SDL_Texture = null;

/// The raw bytes of the board image.
const board_image: [:0]const u8 = @embedFile("../data/board.png");

var white_king_texture: ?*c.SDL_Texture = null;
var black_king_texture: ?*c.SDL_Texture = null;
var rook_texture: ?*c.SDL_Texture = null;
var bishop_texture: ?*c.SDL_Texture = null;
var gold_texture: ?*c.SDL_Texture = null;
var silver_texture: ?*c.SDL_Texture = null;
var knight_texture: ?*c.SDL_Texture = null;
var lance_texture: ?*c.SDL_Texture = null;
var pawn_texture: ?*c.SDL_Texture = null;
var promoted_rook_texture: ?*c.SDL_Texture = null;
var promoted_bishop_texture: ?*c.SDL_Texture = null;
var promoted_silver_texture: ?*c.SDL_Texture = null;
var promoted_knight_texture: ?*c.SDL_Texture = null;
var promoted_lance_texture: ?*c.SDL_Texture = null;
var promoted_pawn_texture: ?*c.SDL_Texture = null;

const white_king_image: [:0]const u8 = @embedFile("../data/piece.png");
const black_king_image: [:0]const u8 = @embedFile("../data/piece.png");
const rook_image: [:0]const u8 = @embedFile("../data/piece.png");
const bishop_image: [:0]const u8 = @embedFile("../data/piece.png");
const gold_image: [:0]const u8 = @embedFile("../data/piece.png");
const silver_image: [:0]const u8 = @embedFile("../data/piece.png");
const knight_image: [:0]const u8 = @embedFile("../data/knight.png");
const lance_image: [:0]const u8 = @embedFile("../data/lance.png");
const pawn_image: [:0]const u8 = @embedFile("../data/pawn.png");
const promoted_rook_image: [:0]const u8 = @embedFile("../data/piece.png");
const promoted_bishop_image: [:0]const u8 = @embedFile("../data/piece.png");
const promoted_silver_image: [:0]const u8 = @embedFile("../data/piece.png");
const promoted_knight_image: [:0]const u8 = @embedFile("../data/piece.png");
const promoted_lance_image: [:0]const u8 = @embedFile("../data/piece.png");
const promoted_pawn_image: [:0]const u8 = @embedFile("../data/piece.png");

/// The main rendering function - it does *all* the rendering each frame, by
/// calling out to helper functions.
pub fn render(
    renderer: *c.SDL_Renderer,
    state: *const ty.State,
) RenderError!void {
    // Clear the renderer for this frame.
    try sdl.renderClear(renderer);

    // Perform all the rendering logic.
    try renderBoard(renderer);
    try renderMoveHighlighted(renderer, state);
    try renderPieces(renderer, state);

    // Take the rendered state and update the window with it.
    c.SDL_RenderPresent(renderer);
}

fn getKingTexture(
    renderer: *c.SDL_Renderer,
    player: ty.Player,
) RenderError!*c.SDL_Texture {
    return switch (player) {
        .white => getInitTexture(renderer, &white_king_texture, white_king_image),
        .black => getInitTexture(renderer, &black_king_texture, black_king_image),
    };
}

fn getCorePieceTexture(
    renderer: *c.SDL_Renderer,
    piece: ty.Piece,
) RenderError!*c.SDL_Texture {
    return switch (piece) {
        .rook => getInitTexture(renderer, &rook_texture, rook_image),
        .bishop => getInitTexture(renderer, &bishop_texture, bishop_image),
        .gold => getInitTexture(renderer, &gold_texture, gold_image),
        .silver => getInitTexture(renderer, &silver_texture, silver_image),
        .knight => getInitTexture(renderer, &knight_texture, knight_image),
        .lance => getInitTexture(renderer, &lance_texture, lance_image),
        .pawn => getInitTexture(renderer, &pawn_texture, pawn_image),
        .promoted_rook => getInitTexture(renderer, &promoted_rook_texture, promoted_rook_image),
        .promoted_bishop => getInitTexture(renderer, &promoted_bishop_texture, promoted_bishop_image),
        .promoted_silver => getInitTexture(renderer, &promoted_silver_texture, promoted_silver_image),
        .promoted_knight => getInitTexture(renderer, &promoted_knight_texture, promoted_knight_image),
        .promoted_lance => getInitTexture(renderer, &promoted_lance_texture, promoted_lance_image),
        .promoted_pawn => getInitTexture(renderer, &promoted_pawn_texture, promoted_pawn_image),
        else => unreachable,
    };
}

fn getPieceTexture(
    renderer: *c.SDL_Renderer,
    player_piece: ty.PlayerPiece,
) RenderError!*c.SDL_Texture {
    const player = player_piece.player;
    const piece = player_piece.piece;
    return switch (piece) {
        .king => getKingTexture(renderer, player),
        else => getCorePieceTexture(renderer, piece),
    };
}

/// Renders all the pieces on the board.
fn renderPieces(
    renderer: *c.SDL_Renderer,
    state: *const ty.State,
) RenderError!void {
    var moved_piece: ?ty.PlayerPiece = null;
    const moved_from: ?ty.BoardPos =
        if (state.mouse.move.from) |pos| pos.toBoardPos() else null;

    // Render every piece on the board, except for the one (if any) that the
    // player is currently moving.
    for (state.board.tiles, 0..) |row, y| {
        for (row, 0..) |val, x| if (val) |piece| render: {
            if (moved_from) |pos| if (x == pos.x and y == pos.y) {
                moved_piece = piece;
                break :render;
            };

            try sdl.renderCopy(.{
                .renderer = renderer,
                .texture = try getPieceTexture(renderer, piece),
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
    if (moved_piece) |piece| if (state.mouse.move.from) |from| {
        const offset = from.offsetFromGrid();
        try sdl.renderCopy(.{
            .renderer = renderer,
            .texture = try getPieceTexture(renderer, piece),
            .dst_rect = &.{
                .x = state.mouse.pos.x - offset.x,
                .y = state.mouse.pos.y - offset.y,
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

/// Renders the game board.
fn renderBoard(renderer: *c.SDL_Renderer) RenderError!void {
    try sdl.renderCopy(.{
        .renderer = renderer,
        .texture = try getInitTexture(renderer, &board_texture, board_image),
    });
}

/// Get the texture if it's there, or (if `null`) initialize it with the given
/// `raw_data` and then return it.
fn getInitTexture(
    renderer: *c.SDL_Renderer,
    texture: *?*c.SDL_Texture,
    raw_data: [:0]const u8,
) RenderError!*c.SDL_Texture {
    if (texture.*) |tex| {
        return tex;
    }

    const tex = try sdl.rwToTexture(.{
        .renderer = renderer,
        .stream = try sdl.constMemToRw(raw_data),
        .free_stream = true,
        .blend_mode = blend_mode,
    });
    texture.* = tex;
    return tex;
}

const highlight_from: ty.Colour = .{
    .red = 0,
    .green = 0xAA,
    .blue = 0,
    .alpha = ty.Colour.@"opaque" / 4,
};

/// Show the current move (if there is one) on the board by highlighting the
/// tile/square of the selected piece.
fn renderMoveHighlighted(
    renderer: *c.SDL_Renderer,
    state: *const ty.State,
) RenderError!void {
    if (state.mouse.move.from) |from| {
        const board_pos = from.toBoardPos();
        const x: usize = @intCast(board_pos.x);
        const y: usize = @intCast(board_pos.y);
        if (state.board.tiles[y][x] == null) {
            return;
        }

        const offset = from.offsetFromGrid();
        try sdl.renderFillRect(
            renderer,
            &highlight_from,
            &.{
                .x = from.x - offset.x,
                .y = from.y - offset.y,
                .w = tile_size,
                .h = tile_size,
            },
        );
    }
}
