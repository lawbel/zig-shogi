//! This module contains the logic for how each piece moves and what
//! constitutes a valid move.

const checked = @import("rules/checked.zig");
const dropped = @import("rules/dropped.zig");
const moved = @import("rules/moved.zig");
const promoted = @import("rules/promoted.zig");
const types = @import("rules/types.zig");
const valid = @import("rules/valid.zig");

pub usingnamespace checked;
pub usingnamespace dropped;
pub usingnamespace moved;
pub usingnamespace promoted;
pub usingnamespace types;
pub usingnamespace valid;

test {
    // Pull in any test cases from the above sub-modules.

    _ = checked;
    _ = dropped;
    _ = moved;
    _ = promoted;
    _ = types;
    _ = valid;
}
