//! Draw the game pieces on the board, and the piece (if any) the user is
//! currently moving.

const c = @import("../c.zig");
const Error = @import("errors.zig").Error;
const model = @import("../model.zig");
const pixel = @import("../pixel.zig");
const sdl = @import("../sdl.zig");
const State = @import("../state.zig").State;
const texture = @import("../texture.zig");

/// The colour to shade pieces with, if they are being moved around by the user.
pub const piece_shadow_on_board: pixel.Colour = .{
    .red = 0xD4,
    .green = 0xC8,
    .blue = 0xC1,
    .alpha = (pixel.Colour.max_opacity / 5) * 4,
};

/// Renders all the pieces on the board, and the piece (if any) that the user
/// is currently moving.
pub fn showPieces(
    args: struct {
        renderer: *c.SDL_Renderer,
        player: model.Player,
        moved_from: ?pixel.PixelPos,
        mouse_pos: pixel.PixelPos,
        board: model.Board,
    },
) Error!void {
    var moved_piece: ?model.Piece = null;
    var moved_from: ?model.BoardPos = null;
    var shade: ?pixel.Colour = null;

    if (args.moved_from) |pos| {
        moved_from = pos.toBoardPos();
    }

    // Render every piece on the board, except for the one (if any) that the
    // user is currently moving.
    for (args.board.tiles, 0..) |row, y| {
        for (row, 0..) |val, x| {
            const piece = val orelse continue;
            const pos_x: i16 = @intCast(x);
            const pos_y: i16 = @intCast(y);

            if (moved_from) |pos| {
                const owner_is_user = piece.player.eq(args.player);
                if (owner_is_user and x == pos.x and y == pos.y) {
                    moved_piece = piece;
                    shade = piece_shadow_on_board;
                }
            }
            defer shade = null;

            try showPiece(.{
                .renderer = args.renderer,
                .piece = piece,
                .pos = .{
                    .x = pixel.board_top_left.x + (pixel.tile_size * pos_x),
                    .y = pixel.board_top_left.y + (pixel.tile_size * pos_y),
                },
                .shade = shade,
            });
        }
    }

    // We need to render any piece the user may be moving last, so it
    // appears on top of everything else. This falls into the two cases below.

    piece_on_board: {
        const piece = moved_piece orelse break :piece_on_board;
        const from = args.moved_from orelse break :piece_on_board;
        const offset = from.offsetFromBoard();

        try showPiece(.{
            .renderer = args.renderer,
            .piece = piece,
            .pos = .{
                .x = args.mouse_pos.x - offset.x,
                .y = args.mouse_pos.y - offset.y,
            },
        });
    }

    piece_in_hand: {
        const pix_from = args.moved_from orelse break :piece_in_hand;
        const piece = pix_from.toHandPiece() orelse break :piece_in_hand;
        if (!piece.player.eq(args.player)) break :piece_in_hand;
        const offset = pix_from.offsetFromUserHand();
        const count = args.board.getHand(args.player).get(piece.sort) orelse 0;
        if (count == 0) break :piece_in_hand;

        try showPiece(.{
            .renderer = args.renderer,
            .piece = piece,
            .pos = .{
                .x = args.mouse_pos.x - offset.x,
                .y = args.mouse_pos.y - offset.y,
            },
        });
    }
}

/// Renders the given piece at the given location. Optionally, shade the piece
/// with the given colour.
pub fn showPiece(
    args: struct {
        renderer: *c.SDL_Renderer,
        piece: model.Piece,
        pos: sdl.Point,
        shade: ?pixel.Colour = null,
    },
) Error!void {
    const tex = try texture.getPieceTexture(args.renderer, args.piece);

    try sdl.renderCopy(.{
        .renderer = args.renderer,
        .texture = tex,
        .dst_rect = .{
            .x = args.pos.x,
            .y = args.pos.y,
            .w = pixel.tile_size,
            .h = pixel.tile_size,
        },
        .angle = switch (args.piece.player) {
            .white => 180,
            .black => 0,
        },
        .shade = args.shade,
    });
}
