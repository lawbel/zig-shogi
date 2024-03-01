//! Highlights useful information on the game board.

const c = @import("../c.zig");
const colours = @import("colours.zig");
const Error = @import("errors.zig").Error;
const highlight = @import("highlight.zig");
const model = @import("../model.zig");
const rules = @import("../rules.zig");
const State = @import("../state.zig").State;
const std = @import("std");

/// Highlight either player's king if they are in check.
pub fn highlightCheck(
    alloc: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    inline for (@typeInfo(model.Player).Union.fields) |field| {
        const player = @unionInit(model.Player, field.name, {});
        const in_check =
            try rules.checked.isInCheck(alloc, player, state.board);

        if (in_check) {
            const king = .{ .sort = .king, .player = player };
            if (state.board.find(king)) |pos| {
                try highlight.tileCorners(renderer, pos, colours.checked);
            }
        }
    }
}

/// Show the last move (if there is one) on the board by highlighting either:
///
/// * The tile/square that the piece moved from and moved to (if it was a
///   'basic' move).
/// * The tile that the piece was dropped on (if it was a drop).
pub fn highlightLast(
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    const last = state.last_move orelse return;
    const col = colours.last_move;

    switch (last) {
        .basic => |basic| {
            const dest = basic.from.applyMotion(basic.motion) orelse return;
            try highlight.tileSquare(renderer, basic.from, col);
            try highlight.tileSquare(renderer, dest, col);
        },

        .drop => |drop| {
            try highlight.tileSquare(renderer, drop.pos, col);
        },
    }
}

/// Show the current move (if there is one) on the board by highlighting the
/// tile/square of the selected piece, and any possible moves that piece could
/// make.
pub fn highlightCurrent(
    alloc: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    const from_pix = state.mouse.move_from orelse return;

    if (from_pix.toBoardPos()) |from_pos| {
        try highlightCurrentBasic(.{
            .alloc = alloc,
            .renderer = renderer,
            .state = state,
            .pos = from_pos,
        });
    } else if (from_pix.toHandPiece()) |piece| {
        if (!piece.player.eq(state.user)) return;
        const count = state.board.getHand(state.user).get(piece.sort) orelse 0;
        if (count == 0) return;

        try highlightCurrentDrop(.{
            .alloc = alloc,
            .renderer = renderer,
            .state = state,
            .piece = piece,
        });
    }
}

/// Shows the current basic move on the board.
fn highlightCurrentBasic(
    args: struct {
        alloc: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        state: State,
        pos: model.BoardPos,
    },
) Error!void {
    const piece = args.state.board.get(args.pos) orelse return;
    if (!piece.player.eq(args.state.user)) return;

    var moves = try rules.moved.movementsFrom(.{
        .alloc = args.alloc,
        .from = args.pos,
        .board = args.state.board,
    });
    defer moves.deinit();

    for (moves.items) |item| {
        const dest = args.pos.applyMotion(item.motion) orelse continue;
        const col = colours.move_option;

        // Show moves as a dot, and possible captures with corner triangles.
        if (args.state.board.get(dest) == null) {
            try highlight.tileDot(args.renderer, dest, col);
        } else {
            try highlight.tileCorners(args.renderer, dest, col);
        }
    }

    try highlight.tileSquare(args.renderer, args.pos, colours.selected);
}

/// Shows the current move - a drop - on the board.
fn highlightCurrentDrop(
    args: struct {
        alloc: std.mem.Allocator,
        renderer: *c.SDL_Renderer,
        state: State,
        piece: model.Piece,
    },
) Error!void {
    var drops = try rules.dropped.possibleDropsOf(
        args.alloc,
        args.piece,
        args.state.board,
    );
    defer drops.deinit();

    for (drops.items) |pos| {
        if (args.state.board.get(pos) == null) {
            try highlight.tileDot(args.renderer, pos, colours.move_option);
        }
    }
}
