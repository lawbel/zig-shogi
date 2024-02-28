//! The common types needed for calculating possible moves on the board.

const model = @import("../model.zig");
const std = @import("std");

/// A collection of valid possible moves.
pub const Valid = struct {
    basics: Basics,
    drops: Drops,

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

pub const Basics = struct {
    map: std.AutoHashMap(
        model.BoardPos,
        std.ArrayList(Movement),
    ),

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

pub const Drops = struct {
    map: std.AutoHashMap(
        model.Piece,
        std.ArrayList(model.BoardPos),
    ),

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

pub const Promotion = union(enum) {
    cannot_promote,
    can_promote,
    must_promote,
};

/// A possible movement on the board, including promotion information.
pub const Movement = struct {
    motion: model.Motion,
    promotion: Promotion,
};
