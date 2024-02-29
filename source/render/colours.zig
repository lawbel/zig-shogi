//! All the various colours used when rendering the game.

const Colour = @import("../pixel.zig").Colour;

/// The colour to highlight the last move with (if there is one).
pub const last_colour: Colour = .{
    .red = 0,
    .green = 0x77,
    .blue = 0,
    .alpha = Colour.max_opacity / 4,
};

/// The colour to highlight a selected piece in, that the user has started
/// moving.
pub const selected_colour: Colour = .{
    .red = 0,
    .green = 0x33,
    .blue = 0x22,
    .alpha = Colour.max_opacity / 4,
};

/// The colour to highlight a tile with, that is a possible option to move the
/// piece to.
pub const option_colour: Colour = selected_colour;

/// The colour to print the count of pieces in a player's hand.
pub const hand_text_colour: Colour = .{
    .red = 0x79,
    .green = 0x66,
    .blue = 0x41,
};

/// The colour to draw the box showing the piece count for each player's hand.
pub const hand_box_colour: Colour = .{
    .red = 0xDD,
    .green = 0xC8,
    .blue = 0xA1,
};

/// The colour to draw the border of the box which shows the piece count for
/// a player's hand.
pub const hand_box_border_colour: Colour = .{
    .red = 0xA3,
    .green = 0x87,
    .blue = 0x50,
};

/// The colour to shade pieces with, if a player has zero of them in hand.
pub const no_piece_in_hand_shade: Colour = .{
    .red = 0xCC,
    .green = 0xCC,
    .blue = 0xCC,
};
