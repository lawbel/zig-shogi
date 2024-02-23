//! This module deals with the mutable game state that we keep track of as the
//! game progresses.

const c = @import("c.zig");
const fonts = @import("fonts.zig");
const model = @import("model.zig");
const mutex = @import("mutex.zig");
const pixel = @import("pixel.zig");
const std = @import("std");

/// Errors that can occur while working with this state.
pub const Error = fonts.Error || error{CantOpenFont};

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
    /// A move that the CPU player has decided on, that has not yet been
    /// applied to update the board.
    cpu_pending_move: mutex.MutexGuard(model.Move),
    /// The time at which the last frame was shipped out.
    last_frame: u32,
    /// The font in use.
    font: *c.TTF_Font,

    /// Create an initial game state.
    pub fn init(
        args: struct {
            alloc: std.mem.Allocator,
            user: model.Player,
            current_player: model.Player,
            init_frame: u32,
            font: struct {
                match: [:0]const u8,
                pt_size: c_int,
            },
        },
    ) Error!@This() {
        const file_path =
            try fonts.bestFontMatching(args.alloc, args.font.match);
        defer args.alloc.free(file_path);

        const opt = c.TTF_OpenFont(@ptrCast(file_path), args.font.pt_size);
        const ttf: *c.TTF_Font = opt orelse return error.CantOpenFont;

        return .{
            .board = model.Board.init,
            .user = args.user,
            .current_player = args.current_player,
            .mouse = .{
                .pos = .{ .x = 0, .y = 0 },
            },
            .cpu_pending_move = mutex.MutexGuard(model.Move).init(null),
            .last_frame = args.init_frame,
            .font = ttf,
        };
    }

    /// Free the memory associated with this type.
    pub fn deinit(this: *@This()) void {
        c.TTF_CloseFont(this.font);
    }
};
