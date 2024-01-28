# Zig Shogi

The Shogi game, implemented in Zig with the help of SDL2.

Table of Contents:

- [Source Documentation](#source-documentation)
- [Build / Develop](#build--develop)

## Source Documentation

Building documentation for the source code is possible, although a convenient
CLI doesn't seem to exist at time of writing. To build documentation for a
particular module, say `sdl.zig`, run the following bash command from the
project root directory, and then open up `docs/index.html`. This will show docs
for all publicly exposed functions, types, etc.

```sh
zig build-lib ./source/sdl.zig              \
    -femit-docs -fno-emit-bin -fno-soname   \
    --main-mod-path .                       \
    -lc                                     \
    $(pkg-config --cflags      sdl2)        \
    $(pkg-config --libs-only-L sdl2)        \
    $(pkg-config --libs-only-l sdl2)        \
    $(pkg-config --cflags      SDL2_image)  \
    $(pkg-config --libs-only-L SDL2_image)  \
    $(pkg-config --libs-only-l SDL2_image)  \
    $(pkg-config --cflags      SDL2_gfx)    \
    $(pkg-config --libs-only-L SDL2_gfx)    \
    $(pkg-config --libs-only-l SDL2_gfx)
```

(Note: the flags here tell zig to emit only documentation, enable `@embedData`
to access ./data, and link C libs. If running this command in other shells, it
may be necessary to split the result of the command substitutions `$(...)` into
lists of strings - for example, in fish they need changing to
`$(... | string split " ")`.)

## Build / Develop

### Standard Method

You will need the `zig` compiler and the C libraries SDL2, SDL2_image, and
SDL2_gfx installed on your system. Then clone the repo, and:

- To build the program, run `zig build` - this will dump the resulting binary
  in `./zig-out/`
- To build and the run the program, run `zig build run`. This will (re)build
  the program if needed, and then run the executable right after.

### With Nix

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
