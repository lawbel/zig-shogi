//! ...

const c = @import("../c.zig");
const state = @import("../state.zig");
const model = @import("../model.zig");
const std = @import("std");
const highlight = @import("highlight.zig");
const Error = @import("errors.zig").Error;

pub fn show(
    args: struct {
        renderer: *c.SDL_Renderer,
        moves: std.AutoHashMap(state.SelectedMove, void),
        tiles: std.AutoHashMap(model.BoardPos, void),
    },
) Error!void {
    try showTiles(args.renderer, args.tiles);
    try showMoves(args.renderer, args.moves);
}

fn showTiles(
    renderer: *c.SDL_Renderer,
    tiles: std.AutoHashMap(model.BoardPos, void),
) Error!void {
    var iter = tiles.keyIterator();
    while (iter.next()) |tile| {
        try highlight.tileSelect(renderer, tile.*);
    }
}

fn showMoves(
    renderer: *c.SDL_Renderer,
    moves: std.AutoHashMap(state.SelectedMove, void),
) Error!void {
    _ = renderer;
    _ = moves;

    // TODO
}
