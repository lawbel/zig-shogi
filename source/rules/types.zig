//! The common types needed for calculating possible moves on the board.

const model = @import("../model.zig");
const promoted = @import("promoted.zig");
const std = @import("std");

/// A collection of valid possible moves.
pub const Valid = struct {
    basics: Basics,
    drops: Drops,

    /// Initialize this type by allocating memory for it.
    pub fn init(alloc: std.mem.Allocator) @This() {
        const basics = Basics.init(alloc);
        const drops = Drops.init(alloc);
        return .{ .basics = basics, .drops = drops };
    }

    /// Frees the memory associated with all basic moves and drops.
    pub fn deinit(this: *@This()) void {
        this.basics.deinit();
        this.drops.deinit();
    }
};

/// Represents a collection of possible basic moves.
pub const Basics = struct {
    map: std.AutoHashMap(
        model.BoardPos,
        std.ArrayList(Movement),
    ),

    /// Initialize this type by allocating memory for it.
    pub fn init(alloc: std.mem.Allocator) @This() {
        const map = std.AutoHashMap(
            model.BoardPos,
            std.ArrayList(Movement),
        ).init(alloc);

        return .{ .map = map };
    }

    /// Frees the memory associated with these basic moves.
    pub fn deinit(this: *@This()) void {
        var iter = this.map.valueIterator();
        while (iter.next()) |movements| {
            movements.deinit();
        }

        this.map.deinit();
    }
};

/// Represents a collection of possible drops that a player could make.
pub const Drops = struct {
    map: std.AutoHashMap(
        model.Piece,
        std.ArrayList(model.BoardPos),
    ),

    /// Initialize this type by allocating memory for it.
    pub fn init(alloc: std.mem.Allocator) @This() {
        const map = std.AutoHashMap(
            model.Piece,
            std.ArrayList(model.BoardPos),
        ).init(alloc);

        return .{ .map = map };
    }

    /// Frees the memory associated with the drops.
    pub fn deinit(this: *@This()) void {
        var iter = this.map.valueIterator();
        while (iter.next()) |movements| {
            movements.deinit();
        }

        this.map.deinit();
    }
};

/// A possible movement on the board, including promotion information.
pub const Movement = struct {
    motion: model.Motion,
    promotion: promoted.AbleToPromote,
};
