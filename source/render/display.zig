//! The high-level functionality for rendering the game. All other modules
//! `render/mod.zig` provide helpers used here.

const board = @import("board.zig");
const c = @import("../c.zig");
const Error = @import("errors.zig").Error;
const hands = @import("hands.zig");
const moves = @import("moves.zig");
const pieces = @import("pieces.zig");
const sdl = @import("../sdl.zig");
const State = @import("../state.zig").State;
const std = @import("std");

/// The main rendering function - it does *all* the rendering each frame, by
/// calling out to helper functions.
pub fn showGameState(
    alloc: std.mem.Allocator,
    renderer: *c.SDL_Renderer,
    state: State,
) Error!void {
    // Clear the renderer for this frame.
    try sdl.renderClear(renderer);

    // Perform all the rendering logic.
    try board.show(renderer);

    if (state.last_move) |last_move| {
        try moves.highlightLast(renderer, last_move);
    }

    if (state.mouse.move_from) |moved_from| {
        try moves.highlightCurrent(.{
            .alloc = alloc,
            .renderer = renderer,
            .board = state.board,
            .player = state.user,
            .moved_from = moved_from,
        });
    }

    try moves.highlightCheck(alloc, renderer, state.board);

    try hands.showBothPlayers(.{
        .alloc = alloc,
        .renderer = renderer,
        .board = state.board,
        .font = state.font,
    });

    try pieces.showPieces(.{
        .renderer = renderer,
        .player = state.user,
        .moved_from = state.mouse.move_from,
        .mouse_pos = state.mouse.pos,
        .board = state.board,
    });

    // Take the rendered state and update the window with it.
    c.SDL_RenderPresent(renderer);
}