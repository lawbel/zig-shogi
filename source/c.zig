//! The path of least resistance in Zig seems to be consistency with
//! `@cImports` across different modules. It is also practical to centralize
//! these imports into one place for it's own sake, to have one source of
//! truth for our C dependencies. Hence we do so in this file.

pub usingnamespace @cImport({
    // From 'SDL2'.
    @cInclude("SDL2/SDL.h");
    // From 'SDL2_image'.
    @cInclude("SDL2/SDL_image.h");
    // From 'SDL2_gfx'.
    @cInclude("SDL2/SDL2_gfxPrimitives.h");
    // From 'SDL2_ttf'.
    @cInclude("SDL2/SDL_ttf.h");
    // From 'fontconfig'.
    @cInclude("fontconfig/fontconfig.h");
});
