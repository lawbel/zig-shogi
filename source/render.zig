//! This module contains all the rendering logic for this game.
//!
//! Note on errors: the SDL rendering functions can error for various reasons.
//! Currently we have the setup necessary to recognize and handle those errors
//! however we want, but for now we simply early-return if we encounter any
//! error.

const c = @import("c.zig");
const pixel = @import("pixel.zig");
const rules = @import("rules.zig");
const sdl = @import("sdl.zig");
const std = @import("std");
const model = @import("model.zig");
const State = @import("state.zig").State;

/// Target frames per second.
pub const fps: u32 = 60;

/// The blending mode to use for all rendering.
pub const blend_mode: c_int = c.SDL_BLENDMODE_BLEND;

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
var core_piece_images: std.EnumMap(model.Sort, [:0]const u8) = init: {
    var map: std.EnumMap(model.Sort, [:0]const u8) = .{};

    for (@typeInfo(model.Sort).Enum.fields) |field| {
        // Skip over kings, as we handle them seperately due to the need to
        // assign them different images for white and black.
        if (field.value == @intFromEnum(model.Sort.king)) {
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
var core_piece_textures: std.EnumMap(model.Sort, ?*c.SDL_Texture) = init: {
    var map: std.EnumMap(model.Sort, ?*c.SDL_Texture) = .{};

    // We want every key to be initialized so indexing is always safe.
    for (@typeInfo(model.Sort).Enum.fields) |field| {
        map.put(@enumFromInt(field.value), null);
    }

    break :init map;
};

/// The main rendering function - it does *all* the rendering each frame, by
/// calling out to helper functions.
pub fn render(
    renderer: *c.SDL_Renderer,
    state: State,
) sdl.SdlError!void {
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

    inline for (@typeInfo(model.Sort).Enum.fields) |field| {
        const piece: model.Sort = @enumFromInt(field.value);
        if (core_piece_textures.get(piece)) |texture| {
            c.SDL_DestroyTexture(texture);
        }
    }
}

/// Gets the appropriate texture for the given `model.Piece`, possibly
/// initializing it along the way if necessary.
fn getPieceTexture(
    renderer: *c.SDL_Renderer,
    piece: model.Piece,
) sdl.SdlError!*c.SDL_Texture {
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
                return error.SdlLoadTexture;
            };
            image = core_piece_images.get(piece.sort) orelse {
                return error.SdlReadConstMemory;
            };
        },
    }

    return getInitTexture(renderer, texture, image);
}

/// Renders all the pieces on the board.
fn drawPieces(
    renderer: *c.SDL_Renderer,
    state: State,
) sdl.SdlError!void {
    var moved_piece: ?model.Piece = null;
    var moved_from: ?model.BoardPos = null;

    if (state.mouse.move_from) |pos| {
        moved_from = model.BoardPos.fromPixelPos(pos);
    }

    // Render every piece on the board, except for the one (if any) that the
    // user is currently moving.
    for (state.board.tiles, 0..) |row, y| {
        for (row, 0..) |val, x| {
            const piece = val orelse continue;

            if (moved_from) |pos| {
                const owner_is_user = piece.player.eq(state.user);
                if (owner_is_user and x == pos.x and y == pos.y) {
                    moved_piece = piece;
                    continue;
                }
            }

            try renderPiece(
                renderer,
                piece,
                .{
                    .x = pixel.tile_size * @as(c_int, @intCast(x)),
                    .y = pixel.tile_size * @as(c_int, @intCast(y)),
                },
            );
        }
    }

    // We need to render any piece the user may be moving last, so it
    // appears on top of everything else.
    const piece = moved_piece orelse return;
    const from = state.mouse.move_from orelse return;
    const offset = from.offsetFromGrid();

    try renderPiece(
        renderer,
        piece,
        .{
            .x = state.mouse.pos.x - offset.x,
            .y = state.mouse.pos.y - offset.y,
        },
    );
}

/// Renders the given piece at the given location.
fn renderPiece(
    renderer: *c.SDL_Renderer,
    piece: model.Piece,
    pos: struct {
        x: c_int,
        y: c_int,
    },
) sdl.SdlError!void {
    const tex = try getPieceTexture(renderer, piece);

    try sdl.renderCopy(.{
        .renderer = renderer,
        .texture = tex,
        .dst_rect = &.{
            .x = pos.x,
            .y = pos.y,
            .w = pixel.tile_size,
            .h = pixel.tile_size,
        },
        .angle = switch (piece.player) {
            .white => 180,
            .black => 0,
        },
    });
}

/// Renders the game board.
fn drawBoard(renderer: *c.SDL_Renderer) sdl.SdlError!void {
    const tex = try getInitTexture(renderer, &board_texture, board_image);
    try sdl.renderCopy(.{ .renderer = renderer, .texture = tex });
}

/// Get the texture if it's there, or (if `null`) initialize it with the given
/// `raw_data` and then return it.
fn getInitTexture(
    renderer: *c.SDL_Renderer,
    texture: *?*c.SDL_Texture,
    raw_data: [:0]const u8,
) sdl.SdlError!*c.SDL_Texture {
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
const last_colour: pixel.Colour = .{
    .red = 0,
    .green = 0x77,
    .blue = 0,
    .alpha = pixel.Colour.max_opacity / 4,
};

/// The colour to highlight a selected piece in, that the user has started
/// moving.
const selected_colour: pixel.Colour = .{
    .red = 0,
    .green = 0x33,
    .blue = 0x22,
    .alpha = pixel.Colour.max_opacity / 4,
};

/// The colour to highlight a tile with, that is a possible option to move the
/// piece to.
const option_colour: pixel.Colour = selected_colour;

/// Show the last move (if there is one) on the board by highlighting the
/// tile/square that the piece moved from and moved to.
fn highlightLastMove(
    renderer: *c.SDL_Renderer,
    state: State,
) sdl.SdlError!void {
    const last = state.last_move orelse return;
    const dest = last.pos.applyMotion(last.motion) orelse return;

    try highlightTileSquare(renderer, last.pos, last_colour);
    try highlightTileSquare(renderer, dest, last_colour);
}

/// Show the current move (if there is one) on the board by highlighting the
/// tile/square of the selected piece, and any possible moves that piece could
/// make.
fn highlightCurrentMove(
    renderer: *c.SDL_Renderer,
    state: State,
) sdl.SdlError!void {
    const from_pix = state.mouse.move_from orelse return;
    const from_pos = model.BoardPos.fromPixelPos(from_pix);
    const piece = state.board.get(from_pos) orelse return;
    const owner_is_user = piece.player.eq(state.user);

    if (!owner_is_user) {
        return;
    }

    try highlightTileSquare(renderer, from_pos, selected_colour);

    const motions = rules.validMotions(from_pos, state.board).slice();

    for (motions) |motion| {
        const dest = from_pos.applyMotion(motion) orelse continue;
        if (state.board.get(dest) == null) {
            try highlightTileDot(renderer, dest, option_colour);
        } else {
            try highlightTileCorners(renderer, dest, option_colour);
        }
    }
}

/// Highlights the given position on the board, by filling it with the given
/// colour (typically a semi-transparent one).
fn highlightTileSquare(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
    colour: pixel.Colour,
) sdl.SdlError!void {
    try sdl.renderFillRect(
        renderer,
        colour,
        &.{
            .x = tile.x * pixel.tile_size,
            .y = tile.y * pixel.tile_size,
            .w = pixel.tile_size,
            .h = pixel.tile_size,
        },
    );
}

/// Renders a `dot` highlight at the given position on the board.
fn highlightTileDot(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
    colour: pixel.Colour,
) sdl.SdlError!void {
    const tile_size_i: i16 = @intCast(pixel.tile_size);
    const tile_size_f: f32 = @floatFromInt(pixel.tile_size);
    const x: f32 = @floatFromInt(tile.x);
    const y: f32 = @floatFromInt(tile.y);

    try sdl.renderFillCircle(.{
        .renderer = renderer,
        .colour = colour,
        .centre = .{
            .x = @intFromFloat((x + 0.5) * tile_size_f),
            .y = @intFromFloat((y + 0.5) * tile_size_f),
        },
        .radius = tile_size_i / 6,
    });
}

/// The length (in pixels) of the 'baseline' sides of the triangls drawn by
/// `highlightTileCorners`. That is, the length of the sides along the x and y
/// axis. The length of the hypotenuse will then be `sqrt(2)` times this
/// length, as it always cuts at 45 degrees across the corner.
const triangle_size: i16 = 20;

/// Renders a triangle in each corner of the tile at the given position on the
/// board.
fn highlightTileCorners(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
    colour: pixel.Colour,
) sdl.SdlError!void {
    const Corner = struct {
        base: sdl.Vertex,
        x_offset: i16,
        y_offset: i16,
    };

    const corners = [_]Corner{
        // Top left corner.
        .{
            .base = .{
                .x = @intCast(pixel.tile_size * tile.x),
                .y = @intCast(pixel.tile_size * tile.y),
            },
            .x_offset = 1,
            .y_offset = 1,
        },

        // Top right corner.
        .{
            .base = .{
                .x = @intCast(pixel.tile_size * (tile.x + 1)),
                .y = @intCast(pixel.tile_size * tile.y),
            },
            .x_offset = -1,
            .y_offset = 1,
        },

        // Bottom left corner.
        .{
            .base = .{
                .x = @intCast(pixel.tile_size * tile.x),
                .y = @intCast(pixel.tile_size * (tile.y + 1)),
            },
            .x_offset = 1,
            .y_offset = -1,
        },

        // Bottom right corner.
        .{
            .base = .{
                .x = @intCast(pixel.tile_size * (tile.x + 1)),
                .y = @intCast(pixel.tile_size * (tile.y + 1)),
            },
            .x_offset = -1,
            .y_offset = -1,
        },
    };

    inline for (corners) |corner| {
        const horiz_pt = .{
            .x = corner.base.x + (triangle_size * corner.x_offset),
            .y = corner.base.y,
        };
        const vert_pt = .{
            .x = corner.base.x,
            .y = corner.base.y + (triangle_size * corner.y_offset),
        };

        try sdl.renderFillTriangle(
            renderer,
            .{ corner.base, horiz_pt, vert_pt },
            colour,
        );
    }
}
