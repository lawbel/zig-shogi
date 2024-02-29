//! Render an empty game board.

const c = @import("../c.zig");
const Error = @import("errors.zig").Error;
const sdl = @import("../sdl.zig");
const texture = @import("../texture.zig");

/// Renders the game board.
pub fn show(renderer: *c.SDL_Renderer) Error!void {
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
