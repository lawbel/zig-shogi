//! Handle the events that come in every frame, updating the state as
//! appropriate.

const c = @import("c.zig");
const cpu = @import("cpu.zig");
const model = @import("model.zig");
const pixel = @import("pixel.zig");
const PromotionOption = @import("state.zig").PromotionOption;
const rules = @import("rules.zig");
const State = @import("state.zig").State;
const std = @import("std");

/// A scratch variable used for processing SDL events.
var event: c.SDL_Event = undefined;

/// Whether to exit the main loop or not.
pub const QuitOrPass =
    enum { quit, pass };

/// Any error that can occur while processing events.
pub const Error = std.Thread.SpawnError;

/// Process all events that occurred since the last frame. Can throw errors due
/// to a (transitive) call to `std.Thread.spawn`.
pub fn processEvents(
    alloc: std.mem.Allocator,
    state: *State,
) Error!QuitOrPass {
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_MOUSEMOTION => {
                state.mouse.pos.x = @intCast(event.motion.x);
                state.mouse.pos.y = @intCast(event.motion.y);
            },

            c.SDL_MOUSEBUTTONDOWN => {
                state.mouse.move_from = state.mouse.pos;
            },

            c.SDL_MOUSEBUTTONUP => {
                defer state.mouse.move_from = null;

                if (state.current_player.eq(state.user)) {
                    if (event.button.button != c.SDL_BUTTON_LEFT) continue;

                    if (state.user_promotion) |promotion| {
                        try processUserPromotion(alloc, state, promotion);
                    } else {
                        try processUserMove(alloc, state);
                    }
                }
            },

            c.SDL_QUIT => return .quit,

            else => {},
        }
    }

    return .pass;
}

/// Try to interpret the users click as choosing a promotion option. If we can
/// do so, then apply that move to the board and queue up the CPU to decide
/// its' response. Otherwise, return without changing anything.
fn processUserPromotion(
    alloc: std.mem.Allocator,
    state: *State,
    promotion: PromotionOption,
) Error!void {
    const moved = applyUserPromotion(state, promotion);
    if (!moved) return;

    if (state.debug) {
        state.board.debugPrint();
        std.debug.print("\n", .{});
    }

    try queueCpuMove(alloc, state);
}

/// Try to interpret the user's click as a choice of promotion option.
///
/// * If we can do so, then apply that promotion to the board, and return
///   `true` to indicate a move was applied.
/// * Otherwise, do nothing and return `false` to indicate no move made.
fn applyUserPromotion(state: *State, promotion: PromotionOption) bool {
    const pos = state.mouse.pos.toBoardPos() orelse return false;

    const choices = pixel.promotionOverlayAt(promotion.to);
    var move: model.Move.Basic = .{
        .from = promotion.from,
        .motion = .{
            .x = promotion.to.x - promotion.from.x,
            .y = promotion.to.y - promotion.from.y,
        },
        .promoted = undefined,
    };

    for (choices, 0..) |choice, i| {
        if (pos.eq(choice)) {
            move.promoted = pixel.order_of_promotion_choices[i];

            state.board.set(promotion.from, promotion.orig_piece);
            const is_ok = state.board.applyMoveBasic(move);
            std.debug.assert(is_ok);

            state.last_move = .{ .basic = move };
            state.current_player = state.current_player.swap();
            state.user_promotion = null;

            return true;
        }
    }

    return false;
}

fn processUserMove(
    alloc: std.mem.Allocator,
    state: *State,
) Error!void {
    const moved = try applyUserMove(alloc, state);
    if (!moved) return;

    if (state.debug) {
        state.board.debugPrint();
        std.debug.print("\n", .{});
    }
    try queueCpuMove(alloc, state);
}

/// Assumes that the user is currently the one whose turn it is. It works out
/// the move the user has inputted based on the mouse movement, and then tries
/// to apply that move to the board. Returns `true` if the move was valid and
/// successfully applied, or `false` otherwise.
fn applyUserMove(alloc: std.mem.Allocator, state: *State) Error!bool {
    const dest = state.mouse.pos.toBoardPos() orelse return false;
    const src_pix = state.mouse.move_from orelse return false;

    if (src_pix.toBoardPos()) |src| {
        return applyUserMoveBasic(.{
            .alloc = alloc,
            .state = state,
            .src = src,
            .dest = dest,
        });
    } else if (src_pix.toHandPiece()) |piece| {
        if (!piece.player.eq(state.user)) return false;
        return applyUserMoveDrop(.{
            .alloc = alloc,
            .state = state,
            .piece = piece,
            .dest = dest,
        });
    }

    return false;
}

/// Apply the given move for the user. Returns `true` if the move was valid and
/// successfully applied, or `false` otherwise.
fn applyUserMoveBasic(
    args: struct {
        alloc: std.mem.Allocator,
        state: *State,
        src: model.BoardPos,
        dest: model.BoardPos,
    },
) Error!bool {
    const piece = args.state.board.get(args.src) orelse return false;
    if (!piece.player.eq(args.state.user)) return false;

    var able_to_promote: rules.AbleToPromote = undefined;
    if (piece.sort.canPromote()) {
        able_to_promote = rules.ableToPromote(.{
            .src = args.src,
            .dest = args.dest,
            .player = args.state.user,
            .must_promote_in_ranks = rules.mustPromoteInRanks(piece),
        });
    } else {
        able_to_promote = .cannot_promote;
    }

    // User input may be needed, in the `.can_promote` case. This is somewhat
    // subtle - we still need to check whether the move is valid, so proceed
    // for now but remember (by setting `user_input_needed`) that we may need
    // to bail out further down this function.
    var user_input_needed = false;
    const promoted = switch (able_to_promote) {
        .cannot_promote => false,
        .must_promote => true,
        .can_promote => set_flag: {
            user_input_needed = true;
            break :set_flag true;
        },
    };

    const basic_move: model.Move.Basic = .{
        .from = args.src,
        .motion = .{
            .x = args.dest.x - args.src.x,
            .y = args.dest.y - args.src.y,
        },
        .promoted = promoted,
    };
    if (basic_move.motion.x == 0 and basic_move.motion.y == 0) return false;

    const move = .{ .basic = basic_move };
    const is_valid = try rules.isValid(args.alloc, move, args.state.board);
    if (!is_valid) return false;

    const move_ok = args.state.board.applyMoveBasic(basic_move);
    std.debug.assert(move_ok);

    // If we got here and this check passes, the move *is* valid but needs user
    // input to choose whether or not to promote. So:
    //
    // * get the board ready,
    // * store the possible promotion in `state`, and
    // * return `false` as we've not completed a move yet.
    if (user_input_needed) {
        args.state.board.set(args.dest, null);
        args.state.user_promotion = .{
            .from = args.src,
            .to = args.dest,
            .orig_piece = piece,
        };
        return false;
    }

    args.state.last_move = move;
    args.state.current_player = args.state.current_player.swap();

    return true;
}

/// Apply the given drop for the user. Returns `true` if the drop was valid and
/// successfully applied, or `false` otherwise.
fn applyUserMoveDrop(
    args: struct {
        alloc: std.mem.Allocator,
        state: *State,
        piece: model.Piece,
        dest: model.BoardPos,
    },
) Error!bool {
    const drop_move: model.Move.Drop = .{
        .pos = args.dest,
        .piece = args.piece,
    };

    const move = .{ .drop = drop_move };
    const is_valid = try rules.isValid(args.alloc, move, args.state.board);
    if (!is_valid) return false;

    const move_ok = args.state.board.applyMoveDrop(drop_move);
    std.debug.assert(move_ok);
    args.state.last_move = move;
    args.state.current_player = args.state.current_player.swap();

    return true;
}

/// Spawn (and detach) a `std.Thread` in which the CPU will calculate a move to
/// play, and then push that move onto the `cpu_pending_move` MutexGuard.
fn queueCpuMove(
    alloc: std.mem.Allocator,
    state: *State,
) Error!void {
    const thread_config = .{};
    const thread = try std.Thread.spawn(
        thread_config,
        cpu.queueMove,
        .{
            .{
                .alloc = alloc,
                .player = state.user.swap(),
                .board = state.board,
                .dest = &state.cpu_pending_move,
            },
        },
    );

    thread.detach();
}
