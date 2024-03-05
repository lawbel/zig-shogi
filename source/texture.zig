//! Handles working with SDL textures.

const c = @import("c.zig");
const model = @import("model.zig");
const sdl = @import("sdl.zig");
const std = @import("std");

/// Embed a file in the `assets` directory.
fn embedAsset(comptime path: [:0]const u8) [:0]const u8 {
    return @embedFile("../assets/" ++ path);
}

/// The board image.
pub const board_image: [:0]const u8 = embedAsset("board.png");

/// The white king image.
pub const white_king_image: [:0]const u8 = embedAsset("white_king.png");

/// The black king image.
pub const black_king_image: [:0]const u8 = embedAsset("black_king.png");

/// The images for all 'core' pieces - every piece except for the kings.
pub var core_piece_images: std.EnumMap(model.Sort, [:0]const u8) = init: {
    var map: std.EnumMap(model.Sort, [:0]const u8) = .{};

    for (@typeInfo(model.Sort).Enum.fields) |field| {
        // Skip over kings, as we handle them separately due to the need to
        // assign them different images for white and black.
        if (field.value != @intFromEnum(model.Sort.king)) {
            const sort: model.Sort = @enumFromInt(field.value);
            map.put(sort, embedAsset(field.name ++ ".png"));
        }
    }

    break :init map;
};

/// The board texture.
pub var board_texture: ?*c.SDL_Texture = null;

/// The white king texture.
pub var white_king_texture: ?*c.SDL_Texture = null;

/// The black king texture.
pub var black_king_texture: ?*c.SDL_Texture = null;

/// A map from piece sorts to SDL textures.
const PieceTextures = std.EnumMap(model.Sort, ?*c.SDL_Texture);

/// The textures for all 'core' pieces - every piece except for the kings.
pub var core_piece_textures: PieceTextures = init: {
    var map: PieceTextures = .{};

    // We want every key to be initialized so indexing is always safe.
    for (@typeInfo(model.Sort).Enum.fields) |field| {
        map.put(@enumFromInt(field.value), null);
    }

    break :init map;
};

/// Frees the memory associated with the textures:
///
/// * `board_texture`
/// * `white_king_texture`
/// * `black_king_texture`
/// * `core_piece_textures`
pub fn freeTextures() void {
    c.SDL_DestroyTexture(board_texture);
    c.SDL_DestroyTexture(white_king_texture);
    c.SDL_DestroyTexture(black_king_texture);

    inline for (@typeInfo(model.Sort).Enum.fields) |field| {
        const piece: model.Sort = @enumFromInt(field.value);
        if (core_piece_textures.get(piece)) |texture| {
            c.SDL_DestroyTexture(texture);
        }
    }
}

/// Gets the appropriate texture for the given `model.Piece`, possibly
/// initializing it along the way if necessary.
pub fn getPieceTexture(
    renderer: *c.SDL_Renderer,
    piece: model.Piece,
) sdl.Error!*c.SDL_Texture {
    var texture: *?*c.SDL_Texture = undefined;
    var image: [:0]const u8 = undefined;

    switch (piece.sort) {
        .king => switch (piece.player) {
            .white => {
                texture = &white_king_texture;
                image = white_king_image;
            },
            .black => {
                texture = &black_king_texture;
                image = black_king_image;
            },
        },

        else => {
            texture = core_piece_textures.getPtr(piece.sort) orelse {
                return error.CannotLoadTexture;
            };
            image = core_piece_images.get(piece.sort) orelse {
                return error.CannotReadMemory;
            };
        },
    }

    return getInitTexture(renderer, texture, image);
}

/// The blending mode to use for all rendering.
pub const blend_mode: c_int = c.SDL_BLENDMODE_BLEND;

/// Get the texture if it's there, or (if `null`) initialize it with the given
/// `raw_data` and then return it.
pub fn getInitTexture(
    renderer: *c.SDL_Renderer,
    texture: *?*c.SDL_Texture,
    raw_data: [:0]const u8,
) sdl.Error!*c.SDL_Texture {
    if (texture.*) |tex| {
        return tex;
    }

    const stream = try sdl.constMemToRw(raw_data);
    const tex = try sdl.rwToTexture(.{
        .renderer = renderer,
        .stream = stream,
        .free_stream = true,
        .blend_mode = blend_mode,
    });

    texture.* = tex;
    return tex;
}
