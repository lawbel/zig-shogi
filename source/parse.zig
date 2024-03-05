//! This module provides a simple parser for CSA files (a file format for
//! Shogi games). It is only used for testing, so we don't worry much about
//! performance or robustness.

const model = @import("model.zig");
const std = @import("std");

pub const Error = ParseError || CsaError || std.mem.Allocator.Error;

pub const ParseError = error{
    EndOfInput,
    UnexpectedChar,
};

pub const CsaError = error{
    MissingPiece,
    InvalidMove,
};

pub fn parseCsa(
    alloc: std.mem.Allocator,
    content: []const u8,
) Error!std.ArrayList(model.Move) {
    const csa_moves = try csaMoves(alloc, content);
    defer csa_moves.deinit();

    return csaToMoves(alloc, csa_moves);
}

/// Turns a sequence of `CsaMove`s into a sequence of `model.Move`s. This
/// assumes that the given moves were played for a game with no handicap on a
/// standard board.
fn csaToMoves(
    alloc: std.mem.Allocator,
    csa_moves: std.ArrayList(CsaMove),
) Error!std.ArrayList(model.Move) {
    var board = model.Board.init;
    var moves = std.ArrayList(model.Move).init(alloc);
    errdefer moves.deinit();

    for (csa_moves.items) |csa_move| {
        const move = try csaToMove(csa_move, board);
        try moves.append(move);
        const is_ok = board.applyMove(move);
        if (!is_ok) return error.InvalidMove;
    }

    return moves;
}

/// Turns a `CsaMove` into a `model.Move`. This required knowing the current
/// state of the game, as some information is left implicit in the csa format.
///
/// In particular, from simply reading a csa move one cannot tell whether a
/// given move promoted a piece, or if it was *already* promoted and simply
/// moved around.
fn csaToMove(move: CsaMove, board: model.Board) Error!model.Move {
    switch (move) {
        .drop => |drop| return .{ .drop = drop },
        .basic => |basic| {
            const orig_piece = board.get(basic.from) orelse {
                return error.MissingPiece;
            };

            const promoted = !orig_piece.eq(basic.final_piece);
            return .{
                .basic = .{
                    .from = basic.from,
                    .motion = basic.motion,
                    .promoted = promoted,
                },
            };
        },
    }
}

/// Similar to `model.Move`, but differs for basic moves. To turn this into
/// one of our `model.Move`s requires keeping track of the board state and
/// how it changes every turn - see `csaToMove` for details.
const CsaMove = union(enum) {
    basic: struct {
        from: model.BoardPos,
        motion: model.Motion,
        final_piece: model.Piece,
    },

    drop: model.Move.Drop,
};

/// Reads a `.csa` file and returns a list of the moves contained inside.
/// Doesn't attempt to properly parse or validate the file structure - it
/// simply assumes that it is valid, and that it contains a game with no
/// handicap on a standard board. It then skips any lines which don't look like
/// moves, and parses those that do.
fn csaMoves(
    alloc: std.mem.Allocator,
    input: []const u8,
) Error!std.ArrayList(CsaMove) {
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    var moves = std.ArrayList(CsaMove).init(alloc);
    errdefer moves.deinit();

    while (lines.next()) |line| {
        const move = csaMove(line) catch continue;
        try moves.append(move);
    }

    return moves;
}

fn csaMove(input: []const u8) ParseError!CsaMove {
    if (input.len < 7) return error.EndOfInput;

    const player = try csaPlayer(input[0]);
    const src_opt = try csaPos(input[1..3]);
    const dest_opt = try csaPos(input[3..5]);
    const sort = try csaSort(input[5..7]);

    const dest = dest_opt orelse return error.UnexpectedChar;
    const piece = .{ .sort = sort, .player = player };

    if (src_opt) |src| {
        const motion = .{
            .x = dest.x - src.x,
            .y = dest.y - src.y,
        };
        const basic = .{
            .final_piece = piece,
            .from = src,
            .motion = motion,
        };
        return .{ .basic = basic };
    } else {
        const drop = .{ .pos = dest, .piece = piece };
        return .{ .drop = drop };
    }
}

test "csaMove example 1" {
    const move = "+2726FU";
    const expected: ?CsaMove = .{
        .basic = .{
            .from = .{ .x = 1, .y = 6 },
            .motion = .{ .x = 0, .y = -1 },
            .final_piece = .{ .sort = .pawn, .player = .black },
        },
    };
    const actual: ?CsaMove = csaMove(move) catch null;
    try std.testing.expectEqualDeep(expected, actual);
}

test "csaMove example 2" {
    const move = "-3243GI";
    const expected: ?CsaMove = .{
        .basic = .{
            .from = .{ .x = 2, .y = 1 },
            .motion = .{ .x = 1, .y = 1 },
            .final_piece = .{ .sort = .silver, .player = .white },
        },
    };
    const actual: ?CsaMove = csaMove(move) catch null;
    try std.testing.expectEqualDeep(expected, actual);
}

/// Returns which player this is.
fn csaPlayer(char: u8) ParseError!model.Player {
    return switch (char) {
        '-' => .white,
        '+' => .black,
        else => error.UnexpectedChar,
    };
}

/// Performs the translation from standard shogi notation (numbering 1-9,
/// left-to-right and top-to-bottom) to the coordinate system we
/// use internally (numbering 0-8, left-to-right and top-to-bottom).
///
/// Note that this may return `null`, which has a special meaning of
/// 'not any rank/file' and is used when a piece is dropped from hand.
fn csaCoord(char: u8) ParseError!?i8 {
    if (char < '0' or '9' < char) return error.UnexpectedChar;

    const standard: i8 = @intCast(char - '0');
    return if (standard > 0) standard - 1 else null;
}

/// Performs the translation from standard shogi notation to the coordinate
/// system we use internally. May return `null`, which has a special meaning of
/// 'not any position on the board' and is used when a piece is dropped from
/// hand.
fn csaPos(chars: []const u8) ParseError!?model.BoardPos {
    const x = try csaCoord(chars[0]);
    const y = try csaCoord(chars[1]);
    return if (x == null or y == null) null else .{ .x = x.?, .y = y.? };
}

/// Returns what sort of piece this is.
fn csaSort(chars: []const u8) ParseError!model.Sort {
    if (std.mem.eql(u8, chars, "OU")) return .king;
    if (std.mem.eql(u8, chars, "HI")) return .rook;
    if (std.mem.eql(u8, chars, "KA")) return .bishop;
    if (std.mem.eql(u8, chars, "KI")) return .gold;
    if (std.mem.eql(u8, chars, "GI")) return .silver;
    if (std.mem.eql(u8, chars, "KE")) return .knight;
    if (std.mem.eql(u8, chars, "KY")) return .lance;
    if (std.mem.eql(u8, chars, "FU")) return .pawn;
    if (std.mem.eql(u8, chars, "RY")) return .promoted_rook;
    if (std.mem.eql(u8, chars, "UM")) return .promoted_bishop;
    if (std.mem.eql(u8, chars, "NG")) return .promoted_silver;
    if (std.mem.eql(u8, chars, "NK")) return .promoted_knight;
    if (std.mem.eql(u8, chars, "NY")) return .promoted_lance;
    if (std.mem.eql(u8, chars, "TO")) return .promoted_pawn;

    return error.UnexpectedChar;
}
