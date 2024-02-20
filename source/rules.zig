//! This module contains the logic for how each piece moves and what
//! constitutes a valid move.

pub const checked = @import("rules/checked.zig");
pub const dropped = @import("rules/dropped.zig");
pub const moved = @import("rules/moved.zig");
pub const types = @import("rules/types.zig");
pub const valid = @import("rules/valid.zig");

test {
    // Pull in any test cases from the above sub-modules.

    _ = checked;
    _ = dropped;
    _ = moved;
    _ = types;
    _ = valid;
}
