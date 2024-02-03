//! This module contains all the rendering logic for this game.
//!
//! Note on errors: the SDL rendering functions can error for various reasons.
//! Currently we have the setup necessary to recognize and handle those errors
//! however we want, but for now we simply early-return if we encounter any
//! error.

const c = @import("c.zig");
const rules = @import("rules.zig");
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
    RenderFillCircle,
    RenderReadConstMemory,
    RenderLoadTexture,
};

/// Target frames per second.
pub const fps: u32 = 60;

/// The blending mode to use for all rendering.
pub const blend_mode: c_int = c.SDL_BLENDMODE_BLEND;

/// The size (in pixels) of one tile/square on the game board.
pub const tile_size: c_int = 70;

/// Embed a file in the `data` directory.
fn embedData(comptime path: [:0]const u8) [:0]const u8 {
    return @embedFile("../data/" ++ path);
}

/// The board image.
const board_image: [:0]const u8 = embedData("board.png");

/// The white king image.
const white_king_image: [:0]const u8 = embedData("white_king.png");

/// The black king image.
const black_king_image: [:0]const u8 = embedData("black_king.png");

/// The images for all 'core' pieces - every piece except for the kings.
var core_piece_images: std.EnumMap(ty.Sort, [:0]const u8) = init: {
    var map: std.EnumMap(ty.Sort, [:0]const u8) = .{};

    for (@typeInfo(ty.Sort).Enum.fields) |field| {
        // Skip over kings, as we handle them seperately due to the need to
        // assign them different images for white and black.
        if (field.value == @intFromEnum(ty.Sort.king)) {
            continue;
        }

        map.put(
            @enumFromInt(field.value),
            embedData(field.name ++ ".png"),
        );
    }

    break :init map;
};

/// The board texture.
var board_texture: ?*c.SDL_Texture = null;

/// The white king texture.
var white_king_texture: ?*c.SDL_Texture = null;

/// The black king texture.
var black_king_texture: ?*c.SDL_Texture = null;

/// The textures for all 'core' pieces - every piece except for the kings.
var core_piece_textures: std.EnumMap(ty.Sort, ?*c.SDL_Texture) = init: {
    var map: std.EnumMap(ty.Sort, ?*c.SDL_Texture) = .{};

    // We want every key to be initialized so indexing is always safe.
    for (@typeInfo(ty.Sort).Enum.fields) |field| {
        map.put(@enumFromInt(field.value), null);
    }

    break :init map;
};

/// The main rendering function - it does *all* the rendering each frame, by
/// calling out to helper functions.
pub fn render(
    renderer: *c.SDL_Renderer,
    state: ty.State,
) RenderError!void {
    // Clear the renderer for this frame.
    try sdl.renderClear(renderer);

    // Perform all the rendering logic.
    try drawBoard(renderer);
    try highlightLastMove(renderer, state);
    try highlightCurrentMove(renderer, state);
    try drawPieces(renderer, state);

    // Take the rendered state and update the window with it.
    c.SDL_RenderPresent(renderer);
}

/// Frees the memory associated with the textures:
///
/// * `board_texture`
/// * `white_king_texture`
/// * `black_king_texture`
/// * `core_piece_textures`
pub fn freeTextures() void {
    c.SDL_DestroyTexture(board_texture);
    c.SDL_DestroyTexture(white_king_texture);
    c.SDL_DestroyTexture(black_king_texture);

    inline for (@typeInfo(ty.Sort).Enum.fields) |field| {
        const piece: ty.Sort = @enumFromInt(field.value);
        if (core_piece_textures.get(piece)) |texture| {
            c.SDL_DestroyTexture(texture);
        }
    }
}

/// Gets the appropriate texture for the given `ty.Piece`, possibly
/// initializing it along the way if necessary.
fn getPieceTexture(
    renderer: *c.SDL_Renderer,
    piece: ty.Piece,
) RenderError!*c.SDL_Texture {
    var texture: *?*c.SDL_Texture = undefined;
    var image: [:0]const u8 = undefined;

    switch (piece.sort) {
        .king => switch (piece.player) {
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
            texture = core_piece_textures.getPtr(piece.sort) orelse {
                return error.RenderLoadTexture;
            };
            image = core_piece_images.get(piece.sort) orelse {
                return error.RenderReadConstMemory;
            };
        },
    }

    return getInitTexture(renderer, texture, image);
}

/// Renders all the pieces on the board.
fn drawPieces(
    renderer: *c.SDL_Renderer,
    state: ty.State,
) RenderError!void {
    var moved_piece: ?ty.Piece = null;
    var moved_from: ?ty.BoardPos = null;

    if (state.mouse.move.from) |pos| {
        moved_from = pos.toBoardPos();
    }

    // Render every piece on the board, except for the one (if any) that the
    // user is currently moving.
    for (state.board.tiles, 0..) |row, y| {
        for (row, 0..) |val, x| {
            const piece = val orelse continue;

            if (moved_from) |pos| {
                const owner_is_user = ty.Player.eq(piece.player, state.user);
                if (owner_is_user and x == pos.x and y == pos.y) {
                    moved_piece = piece;
                    continue;
                }
            }

            try renderPiece(.{
                .renderer = renderer,
                .piece = piece,
                .x = tile_size * @as(c_int, @intCast(x)),
                .y = tile_size * @as(c_int, @intCast(y)),
            });
        }
    }

    // We need to render any piece the user may be moving last, so it
    // appears on top of everything else.
    const piece = moved_piece orelse return;
    const from = state.mouse.move.from orelse return;
    const offset = from.offsetFromGrid();

    try renderPiece(.{
        .renderer = renderer,
        .piece = piece,
        .x = state.mouse.pos.x - offset.x,
        .y = state.mouse.pos.y - offset.y,
    });
}

/// Renders the given piece at the given location.
fn renderPiece(
    args: struct {
        renderer: *c.SDL_Renderer,
        piece: ty.Piece,
        x: c_int,
        y: c_int,
    },
) RenderError!void {
    const tex = try getPieceTexture(args.renderer, args.piece);

    try sdl.renderCopy(.{
        .renderer = args.renderer,
        .texture = tex,
        .dst_rect = &.{
            .x = args.x,
            .y = args.y,
            .w = tile_size,
            .h = tile_size,
        },
        .angle = switch (args.piece.player) {
            .white => 180,
            .black => 0,
        },
    });
}

/// Renders the game board.
fn drawBoard(renderer: *c.SDL_Renderer) RenderError!void {
    const tex = try getInitTexture(renderer, &board_texture, board_image);
    try sdl.renderCopy(.{ .renderer = renderer, .texture = tex });
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

    const stream = try sdl.constMemToRw(raw_data);
    const tex = try sdl.rwToTexture(.{
        .renderer = renderer,
        .stream = stream,
        .free_stream = true,
        .blend_mode = blend_mode,
    });

    texture.* = tex;
    return tex;
}

/// The colour to highlight the last move with (if there is one).
const last_colour: ty.Colour = .{
    .red = 0,
    .green = 0x33,
    .blue = 0x22,
    .alpha = ty.Colour.@"opaque" / 4,
};

/// The colour to highlight a selected piece in, that the user has started
/// moving.
const selected_colour: ty.Colour = .{
    .red = 0,
    .green = 0xAA,
    .blue = 0,
    .alpha = ty.Colour.@"opaque" / 4,
};

/// The colour to highlight a tile with, that is a possible option to move the
/// piece to.
const option_colour: ty.Colour = selected_colour;

/// The colour to highlight a tile with, when the piece on that tile can be
/// captured.
const capture_colour: ty.Colour = .{
    .red = 0x77,
    .green = 0,
    .blue = 0,
    .alpha = ty.Colour.@"opaque" / 4,
};

/// Show the last move (if there is one) on the board by highlighting the
/// tile/square that the piece moved from and moved to.
fn highlightLastMove(
    renderer: *c.SDL_Renderer,
    state: ty.State,
) RenderError!void {
    const last = state.last orelse return;
    const move = last.pos.makeMove(last.move) orelse return;

    try highlightTileSquare(renderer, last.pos, last_colour);
    try highlightTileSquare(renderer, move, last_colour);
}

/// Show the current move (if there is one) on the board by highlighting the
/// tile/square of the selected piece, and any possible moves that piece could
/// make.
fn highlightCurrentMove(
    renderer: *c.SDL_Renderer,
    state: ty.State,
) RenderError!void {
    const from_pix = state.mouse.move.from orelse return;
    const from_pos = from_pix.toBoardPos();
    const piece = state.board.get(from_pos) orelse return;
    const owner_is_user = ty.Player.eq(piece.player, state.user);

    if (owner_is_user) {
        try doHighlightCurrentMove(renderer, state, from_pos);
    }
}

/// Does the main work for the `highlightCurrentMove` function, by highlighting
/// the given position and any possible valid moves that the piece at that
/// position could make.
fn doHighlightCurrentMove(
    renderer: *c.SDL_Renderer,
    state: ty.State,
    tile: ty.BoardPos,
) RenderError!void {
    try highlightTileSquare(renderer, tile, selected_colour);

    const moves = rules.validMoves(tile, state.board).slice();
    for (moves) |move| {
        const dest = tile.makeMove(move) orelse continue;
        if (state.board.get(dest) == null) {
            try highlightTileDot(renderer, dest, option_colour);
        } else {
            try highlightTileSquare(renderer, dest, capture_colour);
        }
    }
}

/// Highlights the given position on the board, by filling it with the given
/// colour (typically a semi-transparent one).
fn highlightTileSquare(
    renderer: *c.SDL_Renderer,
    tile: ty.BoardPos,
    colour: ty.Colour,
) RenderError!void {
    try sdl.renderFillRect(
        renderer,
        colour,
        &.{
            .x = tile.x * tile_size,
            .y = tile.y * tile_size,
            .w = tile_size,
            .h = tile_size,
        },
    );
}

/// Renders a `dot` highlight at the given position on the board.
fn highlightTileDot(
    renderer: *c.SDL_Renderer,
    tile: ty.BoardPos,
    colour: ty.Colour,
) RenderError!void {
    const tile_size_i: i16 = @intCast(tile_size);
    const tile_size_f: f32 = @floatFromInt(tile_size);
    const x: f32 = @floatFromInt(tile.x);
    const y: f32 = @floatFromInt(tile.y);

    try sdl.renderFillCircle(.{
        .renderer = renderer,
        .colour = colour,
        .x = @intFromFloat((x + 0.5) * tile_size_f),
        .y = @intFromFloat((y + 0.5) * tile_size_f),
        .radius = tile_size_i / 6,
    });
}
