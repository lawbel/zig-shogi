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
pub const QuitOrPass =
    enum { quit, pass };

/// Process all events that occured since the last frame.
pub fn processEvents(state: *ty.State) QuitOrPass {
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

            c.SDL_QUIT => return .quit,

            else => {},
        }
    }

    return .pass;
}

/// Process the left-mouse button being released.
fn leftClickRelease(state: *ty.State) void {
    defer state.mouse.move.from = null;

    // If the user is not the current player, then we ignore their move input.
    if (ty.Player.not_eq(state.current, state.user)) {
        return;
    }

    const dest = state.mouse.pos.toBoardPos();
    const src_pix = (state.mouse.move.from) orelse return;

    const src = src_pix.toBoardPos();
    const move = ty.Move{
        .x = dest.x - src.x,
        .y = dest.y - src.y,
    };

    var user_owns_piece = false;
    if (state.board.get(src)) |piece| {
        user_owns_piece = ty.Player.eq(piece.player, state.user);
    }

    if (move.isValid(src, state.board) and user_owns_piece) {
        processMove(.{
            .state = state,
            .src = src,
            .dest = dest,
            .move = move,
        });
    }

    state.current.swap();
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
    const piece = dest_piece orelse return;
    const sort = piece.sort.demote();

    var hand: *std.EnumMap(ty.Sort, i8) = undefined;
    if (args.state.user == .white) {
        hand = &args.state.board.hand.white;
    } else {
        hand = &args.state.board.hand.black;
    }

    if (hand.getPtr(sort)) |count| {
        count.* += 1;
    }
}
