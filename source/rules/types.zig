//! The common types needed for calculating possible moves on the board.

const model = @import("../model.zig");
const std = @import("std");

/// A collection of valid possible moves.
pub const Valid = struct {
    basics: std.ArrayList(Basic),
    drops: std.ArrayList(Drop),

    /// A collection of basic moves. Is similar to `model.Move.Basic`, but
    /// contains 'could_promote: bool' instead of 'promoted: bool'.
    pub const Basic = struct {
        from: model.BoardPos,
        movements: std.ArrayList(Movement),

        /// The total number of possible moves encoded by this type.
        pub fn count(this: @This()) usize {
            var total: usize = 0;
            for (this.movements.items) |item| {
                total += item.count();
            }
            return total;
        }

        /// Returns the nth possible move encoded by this type.
        pub fn index(this: @This(), i: usize) ?model.Move.Basic {
            var cursor: usize = 0;

            for (this.movements.items) |item| {
                cursor += item.count();
                if (cursor < i) continue;

                const promoted: bool = switch (item.promotion) {
                    .cannot_promote => false,
                    .can_promote => (cursor - i) % 2 != 0,
                    .must_promote => true,
                };
                return .{
                    .from = this.from,
                    .motion = item.motion,
                    .promoted = promoted,
                };
            }

            return null;
        }

        /// Frees the memory associated with this type.
        pub fn deinit(this: *@This()) void {
            this.movements.deinit();
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

        /// The total number of possible moves encoded by this type.
        pub fn count(this: @This()) usize {
            return if (this.promotion == .can_promote) 2 else 1;
        }
    };

    /// A collection of valid drops. Is similar to `model.Move.Drop`.
    pub const Drop = struct {
        piece: model.Piece,
        drops: std.ArrayList(model.BoardPos),

        /// The total number of possible moves encoded by this type.
        pub fn count(this: @This()) usize {
            return this.drops.items.len;
        }

        /// Returns the nth possible move encoded by this type.
        pub fn index(this: @This(), i: usize) ?model.Move.Drop {
            if (i < this.drops.items.len) {
                return .{
                    .pos = this.drops.items[i],
                    .piece = this.piece,
                };
            }
            return null;
        }

        /// Frees the memory associated with this type.
        pub fn deinit(this: *@This()) void {
            this.drops.deinit();
        }
    };

    /// The total number of possible moves encoded by this type.
    pub fn count(this: @This()) usize {
        return this.countBasics() + this.countDrops();
    }

    /// The total number of possible basic moves encoded by this type.
    pub fn countBasics(this: @This()) usize {
        var total: usize = 0;
        for (this.basics.items) |item| {
            total += item.count();
        }
        return total;
    }

    /// The total number of possible drops encoded by this type.
    pub fn countDrops(this: @This()) usize {
        var total: usize = 0;
        for (this.drops.items) |item| {
            total += item.count();
        }
        return total;
    }

    /// Returns the nth possible move encoded by this type.
    pub fn index(this: @This(), i: usize) ?model.Move {
        const basic_len = this.countBasics();
        const drop_len = this.countDrops();

        if (i < basic_len) {
            const basic = this.indexBasics(i) orelse return null;
            return .{ .basic = basic };
        } else if (i < basic_len + drop_len) {
            const drop = this.indexDrops(i - basic_len) orelse return null;
            return .{ .drop = drop };
        }

        return null;
    }

    /// Returns the nth possible basic move encoded by this type.
    pub fn indexBasics(this: @This(), i: usize) ?model.Move.Basic {
        var cursor: usize = 0;
        for (this.basics.items) |item| {
            cursor += item.count();
            if (cursor > i) {
                return item.index(cursor - i);
            }
        }
        return null;
    }

    /// Returns the nth possible drop encoded by this type.
    pub fn indexDrops(this: @This(), i: usize) ?model.Move.Drop {
        var cursor: usize = 0;
        for (this.drops.items) |item| {
            cursor += item.count();
            if (cursor > i) {
                return item.index(cursor - i);
            }
        }
        return null;
    }

    /// Frees the memory associated with this type.
    pub fn deinit(this: *@This()) void {
        this.deinitBasics();
        this.deinitDrops();
    }

    /// Frees the memory associated with the basic moves.
    fn deinitBasics(this: *@This()) void {
        for (this.basics.items) |*item| {
            item.deinit();
        }
        this.basics.deinit();
    }

    /// Frees the memory associated with the drops.
    fn deinitDrops(this: *@This()) void {
        for (this.drops.items) |*item| {
            item.deinit();
        }
        this.drops.deinit();
    }
};
