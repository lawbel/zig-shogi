//! TODO: add docs.

const c = @import("../c.zig");
const colours = @import("colours.zig");
const Error = @import("errors.zig").Error;
const model = @import("../model.zig");
const pieces = @import("pieces.zig");
const pixel = @import("../pixel.zig");
const PromotionOption = @import("../state.zig").PromotionOption;
const sdl = @import("../sdl.zig");

const corner_radius = 17;

const border_padding = 7;

pub fn showPromotion(
    renderer: *c.SDL_Renderer,
    promotion: PromotionOption,
) Error!void {
    const full_screen: ?*const c.SDL_Rect = null;
    try sdl.renderFillRect(renderer, colours.promotion_overlay, full_screen);

    const x_pos_base: c_int = @intCast(promotion.to.x);
    const y_pos_base: c_int = @intCast(promotion.to.y);
    const top_left_x: c_int = @intCast(pixel.board_top_left.x);
    const top_left_y: c_int = @intCast(pixel.board_top_left.y);

    // Need to take care not to fall off the edge of the board. So we check if
    // the second position would be out of bounds, and in that case move
    // everything up by one.
    var y_positions: [2]c_int = undefined;
    if (promotion.to.y + 1 < model.Board.size) {
        y_positions[0] = y_pos_base;
        y_positions[1] = y_pos_base + 1;
    } else {
        y_positions[0] = y_pos_base - 1;
        y_positions[1] = y_pos_base;
    }

    const piece_sorts = [2]model.Sort{
        promotion.orig_piece.sort.promote(),
        promotion.orig_piece.sort,
    };

    const top_left: sdl.Vertex = .{
        .x = @as(
            i16,
            @intCast(top_left_x + (pixel.tile_size * x_pos_base)),
        ) - border_padding,
        .y = @as(
            i16,
            @intCast(top_left_y + (pixel.tile_size * y_positions[0])),
        ) - border_padding,
    };
    const tile: i16 = @intCast(pixel.tile_size);
    const bot_right: sdl.Vertex = .{
        .x = top_left.x + tile + (border_padding * 2),
        .y = top_left.y + (tile * 2) + (border_padding * 2),
    };

    try sdl.renderFillRoundedRect(.{
        .renderer = renderer,
        .colour = colours.promotion_box,
        .rect = .{
            .top_left = top_left,
            .bot_right = bot_right,
        },
        .corner_radius = corner_radius,
    });

    for (y_positions, piece_sorts) |y_pos, sort| {
        const piece = .{
            .player = promotion.orig_piece.player,
            .sort = sort,
        };
        try pieces.showPiece(.{
            .renderer = renderer,
            .piece = piece,
            .pos = .{
                .x = top_left_x + (pixel.tile_size * x_pos_base),
                .y = top_left_y + (pixel.tile_size * y_pos),
            },
        });
    }
}
