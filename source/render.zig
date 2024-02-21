//! This module contains all the rendering logic for this game.
//!
//! Note on errors: the SDL rendering functions can error for various reasons.
//! Currently we have the setup necessary to recognize and handle those errors
//! however we want, but for now we simply early-return if we encounter any
//! error.

const c = @import("c.zig");
const model = @import("model.zig");
const pixel = @import("pixel.zig");
const rules = @import("rules.zig");
const sdl = @import("sdl.zig");
const State = @import("state.zig").State;
const std = @import("std");
const texture = @import("texture.zig");

/// Any kind of error that can occur during rendering.
pub const Error = sdl.Error || std.mem.Allocator.Error;

/// The main rendering function - it does *all* the rendering each frame, by
/// calling out to helper functions.
pub fn render(
    alloc: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    // Clear the renderer for this frame.
    try sdl.renderClear(renderer);

    // Perform all the rendering logic.
    try drawBoard(renderer);
    try highlightLastMove(renderer, state);
    try highlightCurrentMove(alloc, renderer, state);
    try drawPieces(renderer, state);

    // Take the rendered state and update the window with it.
    c.SDL_RenderPresent(renderer);
}

/// Renders all the pieces on the board.
fn drawPieces(
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    var moved_piece: ?model.Piece = null;
    var moved_from: ?model.BoardPos = null;

    if (state.mouse.move_from) |pos| {
        moved_from = pos.toBoardPos();
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

            const pos_x: c_int = @intCast(x);
            const pos_y: c_int = @intCast(y);
            const top_left_x: c_int = @intCast(pixel.board_top_left.x);
            const top_left_y: c_int = @intCast(pixel.board_top_left.y);

            try renderPiece(
                renderer,
                piece,
                .{
                    .x = top_left_x + (pixel.tile_size * pos_x),
                    .y = top_left_y + (pixel.tile_size * pos_y),
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
) Error!void {
    const tex = try texture.getPieceTexture(renderer, piece);

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
fn drawBoard(renderer: *c.SDL_Renderer) Error!void {
    const tex = try texture.getInitTexture(
        renderer,
        &texture.board_texture,
        texture.board_image,
    );
    try sdl.renderCopy(.{
        .renderer = renderer,
        .texture = tex,
    });
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

/// Show the last move (if there is one) on the board by highlighting either:
///
/// * The tile/square that the piece moved from and moved to (if it was a
///   'basic' move).
/// * The tile that the piece was dropped on (if it was a drop).
fn highlightLastMove(
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    const last = state.last_move orelse return;

    switch (last) {
        .basic => |basic| {
            const dest = basic.from.applyMotion(basic.motion) orelse return;
            try highlightTileSquare(renderer, basic.from, last_colour);
            try highlightTileSquare(renderer, dest, last_colour);
        },

        .drop => |drop| {
            try highlightTileSquare(renderer, drop.pos, last_colour);
        },
    }
}

/// Show the current move (if there is one) on the board by highlighting the
/// tile/square of the selected piece, and any possible moves that piece could
/// make.
fn highlightCurrentMove(
    alloc: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    const from_pix = state.mouse.move_from orelse return;

    if (from_pix.toBoardPos()) |from_pos| {
        try highlightCurrentMoveBasic(alloc, renderer, state, from_pos);
    } else {
        // TODO: highlight drops
    }
}

/// Shows the current basic move on the board.
fn highlightCurrentMoveBasic(
    alloc: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    state: State,
    pos: model.BoardPos,
) Error!void {
    const piece = state.board.get(pos) orelse return;
    if (!piece.player.eq(state.user)) return;

    var moves = try rules.moved.movementsFrom(.{
        .alloc = alloc,
        .from = pos,
        .board = state.board,
    });
    defer moves.deinit();

    for (moves.items) |item| {
        // TODO: handle item.could_promote?
        const dest = pos.applyMotion(item.motion) orelse continue;
        if (state.board.get(dest) == null) {
            try highlightTileDot(renderer, dest, option_colour);
        } else {
            try highlightTileCorners(renderer, dest, option_colour);
        }
    }

    try highlightTileSquare(renderer, pos, selected_colour);
}

/// Highlights the given position on the board, by filling it with the given
/// colour (typically a semi-transparent one).
fn highlightTileSquare(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
    colour: pixel.Colour,
) Error!void {
    const top_left_x: c_int = @intCast(pixel.board_top_left.x);
    const top_left_y: c_int = @intCast(pixel.board_top_left.y);

    try sdl.renderFillRect(
        renderer,
        colour,
        &.{
            .x = top_left_x + (tile.x * pixel.tile_size),
            .y = top_left_y + (tile.y * pixel.tile_size),
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
) Error!void {
    const tile_size_i: i16 = @intCast(pixel.tile_size);
    const tile_size_f: f32 = @floatFromInt(pixel.tile_size);
    const tile_x: f32 = @floatFromInt(tile.x);
    const tile_y: f32 = @floatFromInt(tile.y);
    const top_left_x: i16 = @intCast(pixel.board_top_left.x);
    const top_left_y: i16 = @intCast(pixel.board_top_left.y);
    const center_x: i16 = @intFromFloat((tile_x + 0.5) * tile_size_f);
    const center_y: i16 = @intFromFloat((tile_y + 0.5) * tile_size_f);

    try sdl.renderFillCircle(.{
        .renderer = renderer,
        .colour = colour,
        .centre = .{
            .x = top_left_x + center_x,
            .y = top_left_y + center_y,
        },
        .radius = tile_size_i / 6,
    });
}

/// The length (in pixels) of the 'baseline' sides of the triangles drawn by
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
) Error!void {
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

    const top_left_x: i16 = @intCast(pixel.board_top_left.x);
    const top_left_y: i16 = @intCast(pixel.board_top_left.y);

    inline for (corners) |corner| {
        const horix_offset = triangle_size * corner.x_offset;
        const horiz_pt = .{
            .x = top_left_x + corner.base.x + horix_offset,
            .y = top_left_y + corner.base.y,
        };

        const vert_offset = triangle_size * corner.y_offset;
        const vert_pt = .{
            .x = top_left_x + corner.base.x,
            .y = top_left_y + corner.base.y + vert_offset,
        };

        const base = .{
            .x = top_left_x + corner.base.x,
            .y = top_left_y + corner.base.y,
        };

        try sdl.renderFillTriangle(
            renderer,
            .{ base, horiz_pt, vert_pt },
            colour,
        );
    }
}
