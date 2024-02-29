//! Implements the logic for piece promotion.

const model = @import("../model.zig");

/// Represents whether a piece is able to (or *must*) promote while moving.
pub const AbleToPromote = union(enum) {
    cannot_promote,
    can_promote,
    must_promote,
};

/// Whether the given piece must be promoted if it is moved into the given rank.
pub fn mustPromoteAtRank(piece: model.Piece, rank: i8) bool {
    const must_promote = mustPromoteInRanks(piece);
    return switch (piece.player) {
        .black => rank < must_promote,
        .white => rank > must_promote,
    };
}

/// The rank beyond which the given piece *must* be promoted if it is moved.
pub fn mustPromoteInRanks(piece: model.Piece) i8 {
    const as_black: i8 = switch (piece.sort) {
        .pawn, .lance => 1,
        .knight => 2,
        else => 0,
    };

    return switch (piece.player) {
        .black => as_black,
        .white => model.Board.size - 1 - as_black,
    };
}

/// Calculates whether or not a piece can, or must, promote when moving from
/// 'src' to 'dest'. Takes as argument `must_promote_in_ranks: i8` which will
/// normally be the result of calling `mustPromoteInRanks`.
pub fn ableToPromote(
    args: struct {
        src: model.BoardPos,
        dest: model.BoardPos,
        player: model.Player,
        must_promote_in_ranks: i8,
    },
) AbleToPromote {
    const must_promote = switch (args.player) {
        .white => args.dest.y > args.must_promote_in_ranks,
        .black => args.dest.y < args.must_promote_in_ranks,
    };
    if (must_promote) {
        return .must_promote;
    }

    const can_promote =
        args.src.inPromotionZoneFor(args.player) or
        args.dest.inPromotionZoneFor(args.player);
    if (can_promote) {
        return .can_promote;
    } else {
        return .cannot_promote;
    }
}
