//! Render the hands for both players - draw the pieces, and show the counts
//! of each.

const c = @import("../c.zig");
const colours = @import("colours.zig");
const Error = @import("errors.zig").Error;
const model = @import("../model.zig");
const pieces = @import("pieces.zig");
const pixel = @import("../pixel.zig");
const sdl = @import("../sdl.zig");
const State = @import("../state.zig").State;
const std = @import("std");

/// Show the state of both players hands.
pub fn showBothPlayers(
    args: struct {
        alloc: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        board: model.Board,
        font: *c.TTF_Font,
    },
) Error!void {
    try showPlayer(.{
        .alloc = args.alloc,
        .renderer = args.renderer,
        .font = args.font,
        .player = .white,
        .hand = args.board.hand.white,
    });
    try showPlayer(.{
        .alloc = args.alloc,
        .renderer = args.renderer,
        .font = args.font,
        .player = .black,
        .hand = args.board.hand.black,
    });
}

/// Render the state of the given players hand - draw the pieces, and show how
/// many of that piece are in the player's hand in a box next to each piece.
fn showPlayer(
    args: struct {
        alloc: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        font: *c.TTF_Font,
        player: model.Player,
        hand: model.Hand,
    },
) Error!void {
    const box_size = 20;
    const box_border = 2;

    const hand_top_left: pixel.PixelPos = switch (args.player) {
        .white => pixel.left_hand_top_left,
        .black => pixel.right_hand_top_left,
    };

    for (pixel.order_of_pieces_in_hand, 0..) |sort, i| {
        const count = args.hand.get(sort) orelse 0;
        const box_width: c_int = if (count < 10) box_size else (box_size * 1.5);

        // Step 1/3 - render the piece.
        const top_left_x: c_int = @intCast(hand_top_left.x);
        const top_left_y: c_int =
            @as(c_int, @intCast(hand_top_left.y)) +
            @as(c_int, @intCast(pixel.tile_size * i));

        // Always render the piece "right way up" by setting `.player=.black`.
        try pieces.showPiece(.{
            .renderer = args.renderer,
            .piece = .{ .player = .black, .sort = sort },
            .pos = .{ .x = top_left_x, .y = top_left_y },
            .shade = if (count > 0) null else colours.no_piece_in_hand,
        });

        // Step 2/3 - render the box we'll show the piece count in.
        const box_x: c_int = @intCast(top_left_x + pixel.tile_size);
        const box_y: c_int = @intCast(top_left_y + pixel.tile_size);

        try sdl.renderFillRect(
            args.renderer,
            colours.hand_box_border,
            &.{
                .x = box_x - box_width,
                .y = box_y - box_size,
                .w = box_width,
                .h = box_size,
            },
        );
        try sdl.renderFillRect(
            args.renderer,
            colours.hand_box,
            &.{
                .x = box_x - box_width + box_border,
                .y = box_y - box_size + box_border,
                .w = box_width - (box_border * 2),
                .h = box_size - (box_border * 2),
            },
        );

        // Step 3/3 - render the count of this piece in hand.
        const str_len = if (count > 0) 1 + std.math.log10(count) else 1;
        const str: [:0]u8 = try args.alloc.allocSentinel(u8, str_len, 0);
        defer args.alloc.free(str);
        _ = std.fmt.formatIntBuf(str, count, 10, .lower, .{});

        try sdl.renderUtf8Text(.{
            .renderer = args.renderer,
            .text = str,
            .font = args.font,
            .style = c.TTF_STYLE_BOLD,
            .colour = colours.hand_text,
            .center = .{
                .x = box_x - @divFloor(box_width, 2),
                .y = box_y - @divFloor(box_size, 2),
            },
        });
    }
}
