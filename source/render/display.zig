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
    try moves.highlightLast(renderer, state);
    try moves.highlightCurrent(alloc, renderer, state);
    try moves.highlightCheck(alloc, renderer, state);
    try hands.showBothPlayers(alloc, renderer, state);
    try pieces.showPieces(renderer, state);

    // Take the rendered state and update the window with it.
    c.SDL_RenderPresent(renderer);
}
