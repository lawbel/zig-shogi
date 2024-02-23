//! The main entry point into the game. This module is intended to be a thin
//! wrapper around the functionality provided by the other modules.

const c = @import("c.zig");
const cpu = @import("cpu.zig");
const event = @import("event.zig");
const init = @import("init.zig");
const model = @import("model.zig");
const render = @import("render.zig");
const sdl = @import("sdl.zig");
const State = @import("state.zig").State;
const std = @import("std");
const texture = @import("texture.zig");
const time = @import("time.zig");

/// The allocator to be used for this program (except for the C code which
/// uses its' own malloc provided by libc).
const Alloc = std.heap.GeneralPurposeAllocator(.{});

/// The main entry point to the game. We chose to free allocated SDL resources,
/// but they could just as well be intentionally leaked as they will be
/// promptly freed by the OS once the process exits.
pub fn main() !void {
    var gpa: Alloc = .{};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    try init.sdlInit();
    defer init.sdlQuit();

    const window = try init.createWindow(.{ .title = "Zig Shogi" });
    defer c.SDL_DestroyWindow(window);

    const renderer = try init.createRenderer(.{ .window = window });
    defer {
        c.SDL_DestroyRenderer(renderer);
        texture.freeTextures();
    }

    var state = try State.init(.{
        .alloc = alloc,
        .user = .black,
        .current_player = .black,
        .init_frame = c.SDL_GetTicks(),
        .font = .{
            .match = ":serif:lang=en:fontformat=TrueType",
            .pt_size = 16,
        },
    });
    defer state.deinit();

    while (true) {
        // Process any events since the last frame. May spawn a thread for the
        // CPU to calculate its next move.
        const result = try event.processEvents(alloc, &state);
        switch (result) {
            .quit => break,
            .pass => {},
        }

        // If the CPU has decided on a move, update the game state with it.
        cpu.applyQueuedMove(&state);

        // Render the current game state.
        try render.render(alloc, renderer, state);

        // Possibly sleep for a short while.
        time.sleepToMatchFps(&state.last_frame);
    }
}
