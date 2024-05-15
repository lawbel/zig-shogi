//! This module provides helper functions for highlighting a tile on the board:
//!
//! * `tileSquare` highlights the entire tile.
//! * `tileDot` draws a dot in the centre of the tile.
//! * `tileCorners` highlights the corners of the tile.
//! * `tileCheck` draws a red dot which fades outwards with a gradient.
//! * `tileSelect` draws a blue circle around the middle of the tile.

const c = @import("../c.zig");
const Error = @import("errors.zig").Error;
const model = @import("../model.zig");
const pixel = @import("../pixel.zig");
const texture = @import("../texture.zig");
const sdl = @import("../sdl.zig");

/// Highlights the given position on the board, by filling it with the given
/// colour (typically a semi-transparent one).
pub fn tileSquare(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
    colour: pixel.Colour,
) Error!void {
    try sdl.renderFillRect(
        renderer,
        colour,
        .{
            .x = pixel.board_top_left.x + (tile.x * pixel.tile_size),
            .y = pixel.board_top_left.y + (tile.y * pixel.tile_size),
            .w = pixel.tile_size,
            .h = pixel.tile_size,
        },
    );
}

/// The size of dot, in pixels, to be drawn by `tileDot`.
const dot_radius: i16 = 9;

/// Renders a `dot` highlight at the given position on the board.
pub fn tileDot(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
    colour: pixel.Colour,
) Error!void {
    const tile_size_f: f32 = @floatFromInt(pixel.tile_size);
    const tile_x: f32 = @floatFromInt(tile.x);
    const tile_y: f32 = @floatFromInt(tile.y);
    const centre_x: i16 = @intFromFloat((tile_x + 0.5) * tile_size_f);
    const centre_y: i16 = @intFromFloat((tile_y + 0.5) * tile_size_f);

    try sdl.renderFillCircle(.{
        .renderer = renderer,
        .colour = colour,
        .centre = .{
            .x = pixel.board_top_left.x + centre_x,
            .y = pixel.board_top_left.y + centre_y,
        },
        .radius = dot_radius,
    });
}

/// The length (in pixels) of the 'baseline' sides of the triangles drawn by
/// `highlightTileCorners`. That is, the length of the sides along the x and y
/// axis. The length of the hypotenuse will then be `sqrt(2)` times this
/// length, as it always cuts at 45 degrees across the corner.
const triangle_size: i16 = 20;

/// Renders a triangle in each corner of the tile at the given position on the
/// board.
pub fn tileCorners(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
    colour: pixel.Colour,
) Error!void {
    const Corner = struct {
        base: sdl.Point,
        x_offset: i16,
        y_offset: i16,
    };

    const corners = [_]Corner{
        // Top left corner.
        .{
            .base = .{
                .x = pixel.tile_size * tile.x,
                .y = pixel.tile_size * tile.y,
            },
            .x_offset = 1,
            .y_offset = 1,
        },
        // Top right corner.
        .{
            .base = .{
                .x = pixel.tile_size * (tile.x + 1),
                .y = pixel.tile_size * tile.y,
            },
            .x_offset = -1,
            .y_offset = 1,
        },
        // Bottom left corner.
        .{
            .base = .{
                .x = pixel.tile_size * tile.x,
                .y = pixel.tile_size * (tile.y + 1),
            },
            .x_offset = 1,
            .y_offset = -1,
        },
        // Bottom right corner.
        .{
            .base = .{
                .x = pixel.tile_size * (tile.x + 1),
                .y = pixel.tile_size * (tile.y + 1),
            },
            .x_offset = -1,
            .y_offset = -1,
        },
    };

    inline for (corners) |corner| {
        const horiz_offset = triangle_size * corner.x_offset;
        const horiz_pt = .{
            .x = pixel.board_top_left.x + corner.base.x + horiz_offset,
            .y = pixel.board_top_left.y + corner.base.y,
        };

        const vert_offset = triangle_size * corner.y_offset;
        const vert_pt = .{
            .x = pixel.board_top_left.x + corner.base.x,
            .y = pixel.board_top_left.y + corner.base.y + vert_offset,
        };

        const base = .{
            .x = pixel.board_top_left.x + corner.base.x,
            .y = pixel.board_top_left.y + corner.base.y,
        };

        try sdl.renderFillTriangle(
            renderer,
            .{ base, horiz_pt, vert_pt },
            colour,
        );
    }
}

/// Highlights the given position on the board, by drawing the 'check' texture
/// at that location.
pub fn tileCheck(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
) Error!void {
    const tex = try texture.getInitTexture(
        renderer,
        &texture.check_texture,
        texture.check_image,
    );

    try sdl.renderCopy(.{
        .renderer = renderer,
        .texture = tex,
        .dst_rect = .{
            .x = pixel.board_top_left.x + (tile.x * pixel.tile_size),
            .y = pixel.board_top_left.y + (tile.y * pixel.tile_size),
            .w = pixel.tile_size,
            .h = pixel.tile_size,
        },
    });
}

/// Highlights the given position on the board, by drawing the 'select' texture
/// at that location.
pub fn tileSelect(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
) Error!void {
    const tex = try texture.getInitTexture(
        renderer,
        &texture.select_texture,
        texture.select_image,
    );

    try sdl.renderCopy(.{
        .renderer = renderer,
        .texture = tex,
        .dst_rect = .{
            .x = pixel.board_top_left.x + (tile.x * pixel.tile_size),
            .y = pixel.board_top_left.y + (tile.y * pixel.tile_size),
            .w = pixel.tile_size,
            .h = pixel.tile_size,
        },
    });
}
