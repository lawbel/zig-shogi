//! All the various colours used when rendering the game.

const Colour = @import("../pixel.zig").Colour;

/// The colour to highlight the last move with (if there is one).
pub const last_move: Colour = .{
    .red = 0x57,
    .green = 0x9A,
    .blue = 0x03,
    .alpha = (Colour.max_opacity / 7) * 2,
};

/// The colour to highlight a selected piece in, that the user has started
/// moving.
pub const selected: Colour = .{
    .red = 0x17,
    .green = 0x33,
    .blue = 0x02,
    .alpha = (Colour.max_opacity / 7) * 2,
};

/// The colour to highlight a tile with, that is a possible option to move the
/// piece to.
pub const move_option: Colour = selected;

/// The colour to highlight the last move with (if there is one).
pub const checked: Colour = .{
    .red = 0x99,
    .green = 0,
    .blue = 0,
    .alpha = Colour.max_opacity / 5,
};

/// The colour to print the count of pieces in a player's hand.
pub const hand_text: Colour = .{
    .red = 0x79,
    .green = 0x66,
    .blue = 0x41,
};

/// The colour to draw the box showing the piece count for each player's hand.
pub const hand_box: Colour = .{
    .red = 0xDD,
    .green = 0xC8,
    .blue = 0xA1,
};

/// The colour to draw the border of the box which shows the piece count for
/// a player's hand.
pub const hand_box_border: Colour = .{
    .red = 0xA3,
    .green = 0x87,
    .blue = 0x50,
};

/// The colour to shade pieces with, if a player has zero of them in hand.
pub const no_piece_in_hand: Colour = .{
    .red = 0xD4,
    .green = 0xC8,
    .blue = 0xC1,
};

/// The colour to shade pieces with, if they are being moved around by the user.
pub const piece_shadow_on_board: Colour = .{
    .red = 0xD4,
    .green = 0xC8,
    .blue = 0xC1,
    .alpha = (Colour.max_opacity / 5) * 4,
};
