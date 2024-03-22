//! Helpers for working with fonts.
//!
//! TODO: handle fonts on windows.

const c = @import("c.zig");
const std = @import("std");

/// All kinds of errors than can occur in this module.
pub const Error = std.mem.Allocator.Error || FontError;

/// Errors that can happen when working with fonts.
const FontError = error{
    BadFontPattern,
    NoFontMatch,
};

/// Finds the font that best matches the given pattern. Caller owns returned
/// string, and must free with the same `alloc` as was given to this function.
///
/// You can use the terminal command `fc-pattern` that fontconfig provides to
/// experiment with pattern syntax. Here are some examples:
///
/// * `:sans` will find a sans-serif font.
/// * `:serif:weight=bold` will find a bold serif font.
/// * `:lang=ja` will find a font supporting Japanese language characters.
/// * `Times-12:italic` will find a font providing 12 point Times Roman in
///   italic.
///
/// For working with SDL_ttf, `:fontformat=TrueType` will be helpful.
///
/// See
/// [here](https://www.freedesktop.org/software/fontconfig/fontconfig-user.html)
/// or run `man fonts-conf` for a reference on these patterns (as well as
/// general information on fontconfig).
pub fn bestFontMatching(
    alloc: std.mem.Allocator,
    pattern: [:0]const u8,
) Error![:0]const u8 {
    // The `FcConfig` we'll use - `null` means use the default one.
    const config: ?*c.FcConfig = null;

    // Create and configure a search pattern.
    const pat: *c.FcPattern = c.FcNameParse(pattern) orelse {
        return error.BadFontPattern;
    };
    defer c.FcPatternDestroy(pat);

    const kind: c.FcMatchKind = c.FcMatchPattern;
    if (c.FcConfigSubstitute(config, pat, kind) != c.FcTrue) {
        return error.OutOfMemory;
    }
    c.FcDefaultSubstitute(pat);

    // Try find a font matching this pattern.
    var result: c.FcResult = undefined;
    const font = c.FcFontMatch(config, pat, &result);
    const matches: *c.FcPattern = switch (result) {
        c.FcResultMatch => font orelse return error.OutOfMemory,
        c.FcResultOutOfMemory => return error.OutOfMemory,
        else => return error.NoFontMatch,
    };
    defer c.FcPatternDestroy(matches);

    // Try get a file path to the matching font.
    var file_path: [*c]u8 = undefined;
    const get_file_path: [:0]const u8 = c.FC_FILE;
    const use_first_match: c_int = 0;
    result = c.FcPatternGetString(
        matches,
        get_file_path,
        use_first_match,
        &file_path,
    );
    switch (result) {
        c.FcResultMatch => {},
        c.FcResultOutOfMemory => return error.OutOfMemory,
        else => return error.NoFontMatch,
    }

    // Allocate a string copy of `file_path` to return to the caller.
    const len: usize = std.mem.len(file_path);
    const new: [:0]u8 = try alloc.allocSentinel(u8, len, 0);
    std.mem.copyForwards(u8, new, file_path[0..len]);
    return @ptrCast(new);
}
