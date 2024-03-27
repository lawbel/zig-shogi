//! This module handles the situation where the user is required to make a
//! choice about promoting one of their pieces.

const c = @import("../c.zig");
const Error = @import("errors.zig").Error;
const model = @import("../model.zig");
const pieces = @import("pieces.zig");
const pixel = @import("../pixel.zig");
const PromotionOption = @import("../state.zig").PromotionOption;
const sdl = @import("../sdl.zig");

/// The corner radius to use for the promotion overlay, in pixels.
const overlay_corner_radius = 15;

/// The padding to use for the promotion overlay, in pixels.
const overlay_padding = 5;

/// The colour to overlay the game screen with when the user is choosing
/// whether or not to promote a piece.
pub const promotion_overlay: pixel.Colour = .{
    .alpha = pixel.Colour.max_opacity / 2,
};

/// The colour for the back the game screen with when the user is choosing
/// whether or not to promote a piece.
pub const promotion_box: pixel.Colour = .{
    .red = 0x33,
    .green = 0x33,
    .blue = 0x33,
    .alpha = (pixel.Colour.max_opacity / 5) * 4,
};

/// Show the promotion choice, by rendering these parts:
///
/// * Dim the whole screen.
/// * Draw a rectangular overlay around the promotion choices.
/// * Draw the two pieces (base and promoted) the user has to choose from.
pub fn showPromotion(
    renderer: *c.SDL_Renderer,
    promotion: PromotionOption,
) Error!void {
    const tile = pixel.tile_size;
    const top_left = pixel.board_top_left;
    const n = 2;

    const positions: [n]model.BoardPos =
        pixel.promotionOverlayAt(promotion.to);

    const piece_sorts: [n]model.Sort = def: {
        const sort = promotion.orig_piece.sort;
        const choice = pixel.order_of_promotion_choices;

        var array: [n]model.Sort = undefined;
        for (0..n) |i| {
            array[i] = if (choice[i]) sort.promote() else sort;
        }

        break :def array;
    };

    // Dim the screen.
    try sdl.renderFillRect(renderer, promotion_overlay, null);

    // Draw an overlay behind the promotion choices.
    try sdl.renderFillRoundedRect(.{
        .renderer = renderer,
        .colour = promotion_box,
        .rect = .{
            .x = top_left.x - overlay_padding + (tile * positions[0].x),
            .y = top_left.y - overlay_padding + (tile * positions[0].y),
            .w = (overlay_padding * 2) + tile,
            .h = (overlay_padding * 2) + (tile * n),
        },
        .corner_radius = overlay_corner_radius,
    });

    // Draw each possible promotion choice.
    for (positions, piece_sorts) |pos, sort| {
        try pieces.showPiece(.{
            .renderer = renderer,
            .piece = .{ .player = promotion.orig_piece.player, .sort = sort },
            .pos = .{
                .x = top_left.x + (tile * pos.x),
                .y = top_left.y + (tile * pos.y),
            },
        });
    }
}
