//! This module provides helper functions for highlighting a tile on the board:
//!
//! * `tileSquare` highlights the entire tile.
//! * `tileDot` draws a dot in the center of the tile.
//! * `tileCorners` highlights the corners of the tile.

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
        const horiz_offset = triangle_size * corner.x_offset;
        const horiz_pt = .{
            .x = top_left_x + corner.base.x + horiz_offset,
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

/// Highlights the given position on the board, by drawing the 'check' texture
/// at that location.
pub fn tileCheck(
    renderer: *c.SDL_Renderer,
    tile: model.BoardPos,
) Error!void {
    const top_left_x: c_int = @intCast(pixel.board_top_left.x);
    const top_left_y: c_int = @intCast(pixel.board_top_left.y);

    const tex = try texture.getInitTexture(
        renderer,
        &texture.check_texture,
        texture.check_image,
    );
    try sdl.renderCopy(.{
        .renderer = renderer,
        .texture = tex,
        .dst_rect = &.{
            .x = top_left_x + (tile.x * pixel.tile_size),
            .y = top_left_y + (tile.y * pixel.tile_size),
            .w = pixel.tile_size,
            .h = pixel.tile_size,
        },
    });
}
