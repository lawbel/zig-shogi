//! TODO: add docs.

const c = @import("../c.zig");
const colours = @import("colours.zig");
const Error = @import("errors.zig").Error;
const model = @import("../model.zig");
const pieces = @import("pieces.zig");
const pixel = @import("../pixel.zig");
const PromotionOption = @import("../state.zig").PromotionOption;
const sdl = @import("../sdl.zig");

const overlay_corner_radius = 17;

const overlay_padding = 7;

pub fn showPromotion(
    renderer: *c.SDL_Renderer,
    promotion: PromotionOption,
) Error!void {
    const tile = pixel.tile_size;
    const top_left = pixel.board_top_left;
    const n = 2;
    const piece_sorts = [n]model.Sort{
        promotion.orig_piece.sort.promote(),
        promotion.orig_piece.sort,
    };

    // Need to take care not to fall off the edge of the board. So we check if
    // the last position would be out of bounds, and in that case move
    // everything up by one.
    var y_positions = [n]i16{ promotion.to.y, promotion.to.y + 1 };
    if (y_positions[n - 1] >= model.Board.size) {
        for (&y_positions) |*pos| {
            pos.* -= 1;
        }
    }

    // Dim the screen.
    try sdl.renderFillRect(renderer, colours.promotion_overlay, null);

    // Draw an overlay behind the promotion choices.
    try sdl.renderFillRoundedRect(.{
        .renderer = renderer,
        .colour = colours.promotion_box,
        .rect = .{
            .x = top_left.x - overlay_padding + (tile * promotion.to.x),
            .y = top_left.y - overlay_padding + (tile * y_positions[0]),
            .w = (overlay_padding * 2) + tile,
            .h = (overlay_padding * 2) + (tile * n),
        },
        .corner_radius = overlay_corner_radius,
    });

    // Draw each possible promotion choice.
    for (y_positions, piece_sorts) |y_pos, sort| {
        try pieces.showPiece(.{
            .renderer = renderer,
            .piece = .{ .player = promotion.orig_piece.player, .sort = sort },
            .pos = .{
                .x = top_left.x + (tile * promotion.to.x),
                .y = top_left.y + (tile * y_pos),
            },
        });
    }
}
