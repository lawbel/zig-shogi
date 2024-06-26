//! Render the hands for both players - draw the pieces, and show the counts
//! of each.

const c = @import("../c.zig");
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

/// The colour to print the count of pieces in a player's hand.
pub const hand_text: pixel.Colour = .{
    .red = 0x79,
    .green = 0x66,
    .blue = 0x41,
};

/// The colour to draw the box showing the piece count for each player's hand.
pub const hand_box: pixel.Colour = .{
    .red = 0xDD,
    .green = 0xC8,
    .blue = 0xA1,
};

/// The colour to draw the border of the box which shows the piece count for
/// a player's hand.
pub const hand_box_border: pixel.Colour = .{
    .red = 0xA3,
    .green = 0x87,
    .blue = 0x50,
};

/// The colour to shade pieces with, if a player has zero of them in hand.
pub const no_piece_in_hand: pixel.Colour = .{
    .red = 0xD4,
    .green = 0xC8,
    .blue = 0xC1,
};

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

    for (pixel.order_of_pieces_in_hand, 0..) |sort, i_usize| {
        const i: i16 = @intCast(i_usize);
        const count = args.hand.get(sort) orelse 0;
        const box_width: i16 = if (count < 10) box_size else (box_size * 1.5);

        // Step 1/3 - render the piece.
        const top_left_x = hand_top_left.x;
        const top_left_y = hand_top_left.y + (pixel.tile_size * i);

        // Always render the piece "right way up" by setting `.player=.black`.
        try pieces.showPiece(.{
            .renderer = args.renderer,
            .piece = .{ .player = .black, .sort = sort },
            .pos = .{ .x = top_left_x, .y = top_left_y },
            .shade = if (count > 0) null else no_piece_in_hand,
        });

        // Step 2/3 - render the box we'll show the piece count in.
        const box_x = top_left_x + pixel.tile_size;
        const box_y = top_left_y + pixel.tile_size;

        try sdl.renderFillRect(
            args.renderer,
            hand_box_border,
            .{
                .x = box_x - box_width,
                .y = box_y - box_size,
                .w = box_width,
                .h = box_size,
            },
        );
        try sdl.renderFillRect(
            args.renderer,
            hand_box,
            .{
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
            .colour = hand_text,
            .centre = .{
                .x = box_x - @divFloor(box_width, 2),
                .y = box_y - @divFloor(box_size, 2),
            },
        });
    }
}
