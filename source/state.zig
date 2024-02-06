//! This module deals with the mutable game state that we keep track of as the
//! game progresses.

const rules = @import("rules.zig");
const pixel = @import("pixel.zig");
const model = @import("model.zig");
const std = @import("std");

/// Our entire game state, which includes a mix of core types like `Board`
/// and things relating to window/mouse state.
pub const State = struct {
    /// The state of the board.
    board: model.Board,
    /// Information needed for mouse interactions.
    mouse: struct {
        /// The current position of the mouse.
        pos: pixel.PixelPos,
        /// If there is a move currently being made with the mouse, then this
        /// stores where the move started - where left-click was first held
        /// down.
        move_from: ?pixel.PixelPos = null,
    },
    /// The last move on the board (if any).
    last_move: ?model.Move = null,
    /// The colour of the human player. The other colour will be the CPU.
    user: model.Player,
    /// The current player.
    current_player: model.Player,

    /// Create an initial game state.
    pub fn init(
        args: struct {
            user: model.Player,
            current_player: model.Player,
        },
    ) @This() {
        return .{
            .board = model.Board.init,
            .user = args.user,
            .current_player = args.current_player,
            .mouse = .{
                .pos = .{ .x = 0, .y = 0 },
            },
        };
    }
};
