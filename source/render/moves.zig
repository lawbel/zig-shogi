//! Highlights useful information on the game board.

const c = @import("../c.zig");
const Error = @import("errors.zig").Error;
const highlight = @import("highlight.zig");
const model = @import("../model.zig");
const pixel = @import("../pixel.zig");
const rules = @import("../rules.zig");
const State = @import("../state.zig").State;
const std = @import("std");

/// Highlight either player's king if they are in check.
pub fn highlightCheck(
    alloc: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    board: model.Board,
) Error!void {
    inline for (@typeInfo(model.Player).Union.fields) |field| {
        const player = @unionInit(model.Player, field.name, {});
        const in_check = try rules.isInCheck(alloc, player, board);

        if (in_check) {
            const king = .{ .sort = .king, .player = player };
            if (board.find(king)) |pos| {
                try highlight.tileCheck(renderer, pos);
            }
        }
    }
}

/// The colour to highlight the last move with (if there is one).
pub const last_move: pixel.Colour = .{
    .red = 0x57,
    .green = 0x9A,
    .blue = 0x03,
    .alpha = (pixel.Colour.max_opacity / 7) * 2,
};

/// Show the last move (if there is one) on the board by highlighting either:
///
/// * The tile/square that the piece moved from and moved to (if it was a
///   'basic' move).
/// * The tile that the piece was dropped on (if it was a drop).
pub fn highlightLast(
    renderer: *c.SDL_Renderer,
    move: model.Move,
) Error!void {
    switch (move) {
        .basic => |basic| {
            const dest = basic.from.applyMotion(basic.motion) orelse return;
            try highlight.tileSquare(renderer, basic.from, last_move);
            try highlight.tileSquare(renderer, dest, last_move);
        },

        .drop => |drop| {
            try highlight.tileSquare(renderer, drop.pos, last_move);
        },
    }
}

/// The colour to highlight a selected piece in, that the user has started
/// moving.
pub const selected: pixel.Colour = .{
    .red = 0x17,
    .green = 0x33,
    .blue = 0x02,
    .alpha = (pixel.Colour.max_opacity / 7) * 2,
};

/// The colour to highlight a tile with, that is a possible option to move the
/// piece to.
pub const move_option: pixel.Colour = selected;

/// Show the current move (if there is one) on the board by highlighting the
/// tile/square of the selected piece, and any possible moves that piece could
/// make. In addition, if the user is hovering over a tile for a possible
/// move, highlight it specially.
pub fn highlightCurrent(
    args: struct {
        alloc: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        board: model.Board,
        player: model.Player,
        moved_from: pixel.PixelPos,
        cur_pos: pixel.PixelPos,
    },
) Error!void {
    if (args.moved_from.toBoardPos()) |from_pos| {
        try highlightCurrentBasic(.{
            .alloc = args.alloc,
            .renderer = args.renderer,
            .board = args.board,
            .player = args.player,
            .pos = from_pos,
            .cur_pos = args.cur_pos,
        });
    } else if (args.moved_from.toHandPiece()) |piece| {
        if (!piece.player.eq(args.player)) return;
        const count = args.board.getHand(args.player).get(piece.sort) orelse 0;
        if (count == 0) return;

        try highlightCurrentDrop(.{
            .alloc = args.alloc,
            .renderer = args.renderer,
            .board = args.board,
            .piece = piece,
            .cur_pos = args.cur_pos,
        });
    }
}

/// Shows the current basic move on the board.
fn highlightCurrentBasic(
    args: struct {
        alloc: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        board: model.Board,
        player: model.Player,
        pos: model.BoardPos,
        cur_pos: pixel.PixelPos,
    },
) Error!void {
    const piece = args.board.get(args.pos) orelse return;
    const current = args.cur_pos.toBoardPos();
    if (!piece.player.eq(args.player)) return;

    var moves = try rules.movementsFrom(.{
        .alloc = args.alloc,
        .from = args.pos,
        .board = args.board,
    });
    defer moves.deinit();

    for (moves.items) |item| {
        const dest = args.pos.applyMotion(item.motion) orelse continue;

        if (current != null and current.?.eq(dest)) {
            try highlight.tileSquare(args.renderer, dest, move_option);
        } else if (args.board.get(dest) == null) {
            try highlight.tileDot(args.renderer, dest, move_option);
        } else {
            try highlight.tileCorners(args.renderer, dest, move_option);
        }
    }

    try highlight.tileSquare(args.renderer, args.pos, selected);
}

/// Shows the current move - a drop - on the board.
fn highlightCurrentDrop(
    args: struct {
        alloc: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        board: model.Board,
        piece: model.Piece,
        cur_pos: pixel.PixelPos,
    },
) Error!void {
    const current = args.cur_pos.toBoardPos();
    var drops = try rules.possibleDropsOf(.{
        .alloc = args.alloc,
        .piece = args.piece,
        .board = args.board,
    });
    defer drops.deinit();

    for (drops.items) |pos| {
        if (current != null and current.?.eq(pos)) {
            try highlight.tileSquare(args.renderer, pos, move_option);
        } else {
            try highlight.tileDot(args.renderer, pos, move_option);
        }
    }
}
