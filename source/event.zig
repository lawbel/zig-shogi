//! Handle the events that come in every frame, updating the state as
//! appropriate.

const c = @import("c.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const std = @import("std");
const ty = @import("types.zig");

/// A scratch variable used for processing SDL events.
var event: c.SDL_Event = undefined;

/// Whether to exit the main loop or not.
pub const MaybeExit =
    enum { exit, pass };

/// Process all events that occured since the last frame.
pub fn processEvents(state: *ty.State) MaybeExit {
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_MOUSEMOTION => {
                state.mouse.pos.x = event.motion.x;
                state.mouse.pos.y = event.motion.y;
            },

            c.SDL_MOUSEBUTTONDOWN => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    state.mouse.move.from = state.mouse.pos;
                }
            },

            c.SDL_MOUSEBUTTONUP => {
                if (event.button.button == c.SDL_BUTTON_LEFT) {
                    leftClickRelease(state);
                }
            },

            c.SDL_QUIT => return .exit,

            else => {},
        }
    }

    return .pass;
}

/// Process the left-mouse button being released.
fn leftClickRelease(state: *ty.State) void {
    const dest = state.mouse.pos.toBoardPos();
    const src_pix = (state.mouse.move.from) orelse return;

    const src = src_pix.toBoardPos();
    const move = ty.Move{
        .x = dest.x - src.x,
        .y = dest.y - src.y,
    };

    if (move.isValid(src, state.board)) {
        processMove(.{
            .state = state,
            .src = src,
            .dest = dest,
            .move = move,
        });
    }

    state.mouse.move.from = null;
}

/// Process the given `ty.Move` by updating the state as appropriate.
fn processMove(
    args: struct {
        state: *ty.State,
        src: ty.BoardPos,
        dest: ty.BoardPos,
        move: ty.Move,
    },
) void {
    const src_piece = args.state.board.get(args.src);
    const dest_piece = args.state.board.get(args.dest);

    // Update the board.
    args.state.board.set(args.src, null);
    args.state.board.set(args.dest, src_piece);

    // Update the last move.
    args.state.last = .{
        .pos = args.src,
        .move = args.move,
    };

    // Add the captured piece (if any) to the players hand.
    if (dest_piece) |piece| {
        var hand: *std.EnumMap(ty.Sort, i8) = undefined;

        if (args.state.player == .white) {
            hand = &args.state.board.hand.white;
        } else {
            hand = &args.state.board.hand.black;
        }

        const sort = piece.sort.demote();
        if (hand.getPtr(sort)) |count| {
            count.* += 1;
        }
    }
}
