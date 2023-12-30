# Zig Shogi

## Build / Install / Develop

### Nix

If you have `nix` available, it will take care of providing `zig`, `zls`, and
SDL2 for you:

- To work on the source code, run `nix develop` (or if you use direnv, simply
  `direnv allow` and it will do this automatically when you enter the
  directory) and you will get `zig`, `zls`, and the `SDL2` library available.
  This way you can load up the project in your editor of choice and get good
  tooling support.
- To build the program, run `nix build` and it will handle all the necessary
  dependencies, there is no need for you to have zig or SDL installed on your
  system. This will dump the resulting binary in `./result/bin/`.
- To build and run the program, simply `nix run` (which, again, will handle
  all dependencies itself).

### Otherwise

You will need `zig` and SDL2 installed on your system. Then:

- To build the program, run `zig build` - this will dump the resulting binary
  in `./zig-out/`
- To build and the run the program, run `zig build run`. This will (re)build
  the program if needed, and then run the executable right after.
