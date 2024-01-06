const c = @cImport(@cInclude("SDL2/SDL.h"));
const types = @import("types.zig");

pub fn render(renderer: *c.SDL_Renderer, board: *types.Board) !void {
    if (c.SDL_SetRenderDrawColor(
        renderer,
        0x44,
        0x22,
        0x11,
        c.SDL_ALPHA_OPAQUE,
    ) < 0) {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to set render draw color: %s",
            c.SDL_GetError(),
        );
        return error.RenderError;
    }

    if (c.SDL_RenderClear(renderer) < 0) {
        c.SDL_LogError(
            c.SDL_LOG_CATEGORY_RENDER,
            "Failed to clear renderer: %s",
            c.SDL_GetError(),
        );
        return error.RenderError;
    }

    c.SDL_RenderPresent(renderer);
}
