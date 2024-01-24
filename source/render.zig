//! This module contains all the rendering logic for this game.
//!
//! Note on errors: the SDL rendering functions can error for various reasons.
//! Currently we have the setup necessary to recognize and handle those errors
//! however we want, but for now we simply early-return if we encounter any
//! error.

const c = @import("c.zig");
const sdl = @import("sdl.zig");
const std = @import("std");
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

/// The board image.
const board_image: [:0]const u8 = @embedFile("../data/board.png");

/// The white king image.
const white_king_image: [:0]const u8 = @embedFile("../data/piece.png");

/// The black king image.
const black_king_image: [:0]const u8 = @embedFile("../data/piece.png");

/// The images for all 'core' pieces - every piece except for the kings.
var core_piece_images: std.EnumMap(ty.Piece, [:0]const u8) = init: {
    var map: std.EnumMap(ty.Piece, [:0]const u8) = .{};

    map.put(.rook, @embedFile("../data/piece.png"));
    map.put(.bishop, @embedFile("../data/piece.png"));
    map.put(.gold, @embedFile("../data/piece.png"));
    map.put(.silver, @embedFile("../data/piece.png"));
    map.put(.knight, @embedFile("../data/knight.png"));
    map.put(.lance, @embedFile("../data/lance.png"));
    map.put(.pawn, @embedFile("../data/pawn.png"));

    map.put(.promoted_rook, @embedFile("../data/piece.png"));
    map.put(.promoted_bishop, @embedFile("../data/piece.png"));
    map.put(.promoted_silver, @embedFile("../data/piece.png"));
    map.put(.promoted_knight, @embedFile("../data/piece.png"));
    map.put(.promoted_lance, @embedFile("../data/piece.png"));
    map.put(.promoted_pawn, @embedFile("../data/piece.png"));

    break :init map;
};

/// The board texture.
var board_texture: ?*c.SDL_Texture = null;

/// The white king texture.
var white_king_texture: ?*c.SDL_Texture = null;

/// The black king texture.
var black_king_texture: ?*c.SDL_Texture = null;

/// The textures for all 'core' pieces - every piece except for the kings.
var core_piece_textures: std.EnumMap(ty.Piece, ?*c.SDL_Texture) = init: {
    var map: std.EnumMap(ty.Piece, ?*c.SDL_Texture) = .{};

    map.put(.rook, null);
    map.put(.bishop, null);
    map.put(.gold, null);
    map.put(.silver, null);
    map.put(.knight, null);
    map.put(.lance, null);
    map.put(.pawn, null);

    map.put(.promoted_rook, null);
    map.put(.promoted_bishop, null);
    map.put(.promoted_silver, null);
    map.put(.promoted_knight, null);
    map.put(.promoted_lance, null);
    map.put(.promoted_pawn, null);

    break :init map;
};

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

fn getPieceTexture(
    renderer: *c.SDL_Renderer,
    player_piece: ty.PlayerPiece,
) RenderError!*c.SDL_Texture {
    const player = player_piece.player;
    const piece = player_piece.piece;

    var texture: *?*c.SDL_Texture = undefined;
    var image: [:0]const u8 = undefined;

    switch (piece) {
        .king => switch (player) {
            .white => {
                texture = &white_king_texture;
                image = white_king_image;
            },
            .black => {
                texture = &black_king_texture;
                image = black_king_image;
            },
        },
        else => {
            texture = core_piece_textures.getPtr(piece) orelse {
                return error.RenderLoadTexture;
            };
            image = core_piece_images.get(piece) orelse {
                return error.RenderReadConstMemory;
            };
        },
    }

    return getInitTexture(renderer, texture, image);
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
            if (moved_from) |pos| {
                const owner = @intFromEnum(piece.player);
                const player = @intFromEnum(state.player);
                if (owner == player and x == pos.x and y == pos.y) {
                    moved_piece = piece;
                    break :render;
                }
            }

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
        const tile = state.board.tiles[y][x];

        if (tile == null) {
            return;
        } else if (tile) |piece| {
            const owner = @intFromEnum(piece.player);
            const player = @intFromEnum(state.player);
            if (owner != player) {
                return;
            }
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
