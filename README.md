# Zig Shogi

The game [Shogi][shogi], implemented in [Zig][zig] using the C
library [SDL2][sdl2].

Table of Contents:

- [Source Documentation](#source-documentation)
- [Build / Develop](#build--develop)

## Source Documentation

Building documentation for the source code is possible, although a convenient
CLI doesn't seem to exist at time of writing. To build documentation for a
particular module, say `source/sdl.zig`, run the following bash command from
the project root directory, and then open up `docs/index.html` in your browser.
This will show docs for all publicly exposed functions, types, etc.

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

Note: the flags here tell zig to emit only documentation, enable `@embedData`
to access the `./data` directory, and link C libs. If running this command in
other shells, it may be necessary to split the result of the command
substitutions `$(...)` into lists of strings - for example, in fish they need
changing to `$(... | string split " ")`.

## Build / Develop

### Standard Method

You will need the `zig` compiler and the C libraries SDL2, SDL2_image, and
SDL2_gfx installed on your system. Then clone the repo, and:

- To run the program, use the command `zig build run`. This will (re)build
  the program if needed, and then run it.
- To build the program, run `zig build` - this will put the resulting binary
  under the `zig-out/bin` directory.
- To run the test suite, there are two methods - `zig test source/test.zig`
  and `zig build test`. The first method seems preferable, as it shows more
  useful information about the results, although neither reports much when all
  test cases are successful.

### With Nix

If you have `nix` available, it will take care of providing `zig`, `zls`, and
all C libraries for you. All you need installed is `nix` itself. To quickly try
out the program, you can simply run the
command `nix run github:lawbel/zig-shogi` - this will fetch this repo and its
dependencies, build it, and run the resulting executable.

Otherwise, clone the repo and then:

- To run the program, simply do `nix run` - this will (re)build the
  project if neccesary and then run it.
- To build the program, use `nix build`. This will handle fetching all
  dependencies, build the project, and put the resulting binary in the
  `result/bin` directory (which is symlinked).
- To browse or work on the source code, run `nix develop` (or if you use
  [direnv][direnv], simply `direnv allow`) and you will get `zig`, `zls`, and
  the SDL2 libraries available in a 'virtual environment'. This way you can
  load up the project in your editor of choice and get LSP support from `zls`,
  as well as having the `zig` compiler available. You can then use any of
  the [above](#standard-method) mentioned `zig ...` commands directly as well.

[direnv]: https://direnv.net
[sdl2]: https://www.libsdl.org
[shogi]: https://en.wikipedia.org/wiki/Shogi
[zig]: https://ziglang.org
