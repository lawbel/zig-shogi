const std = @import("std");
const ty = @import("types.zig");

/// A vector (x, y) representing a move on our board.
pub const Move =
    struct { x: i8, y: i8 };

/// A collection of possible moves on the board.
const Moves = std.BoundedArray(Move, max_moves);

/// An upper bound on the maximum number of possible moves that any piece
/// could have. The case which requires the most possible moves is dropping a
/// new piece onto a near-empty board.
const max_moves: usize = ty.Board.size * ty.Board.size;

/// Returns a list of all
pub fn legal_moves_from(pos: ty.BoardPos, board: ty.Board) Moves {
    const x: usize = @intCast(pos.x);
    const y: usize = @intCast(pos.y);
    const player_piece = board.tiles[y][x] orelse {
        return Moves.init(0);
    };

    switch (player_piece.piece) {
        .king => {
            const moves = [_]Move{
                .{ .x = 1, .y = 0 },
                .{ .x = 1, .y = 1 },
                .{ .x = 0, .y = 1 },
                .{ .x = -1, .y = 1 },
                .{ .x = -1, .y = 0 },
                .{ .x = -1, .y = -1 },
                .{ .x = 0, .y = -1 },
                .{ .x = 1, .y = -1 },
            };
            var arr = Moves.init(moves.len) catch unreachable;
            arr.appendSliceAssumeCapacity(&moves);
            return arr;
        },
        else => unreachable, // TODO
    }
}
