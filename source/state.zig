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
        /// Whether there is a move currently being made with the mouse.
        move: struct {
            /// Where the move started - where left-click was first held down.
            from: ?pixel.PixelPos,
        },
    },
    /// The last move on the board (if any).
    last: ?model.Move = null,
    /// The colour of the human player. The other colour will be the CPU.
    user: model.Player,
    /// The current player.
    current: model.Player,

    /// Create an initial game state.
    pub fn init(
        args: struct {
            user: model.Player,
            current: model.Player,
        },
    ) @This() {
        return .{
            .board = model.Board.init,
            .user = args.user,
            .current = args.current,
            .mouse = .{
                .pos = .{ .x = 0, .y = 0 },
                .move = .{ .from = null },
            },
        };
    }
};
