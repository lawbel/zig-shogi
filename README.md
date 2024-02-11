# Zig Shogi

The game [Shogi][shogi], implemented in [Zig][zig] using the C
library [SDL2][sdl2].

Table of Contents:

- [Build / Develop](#build--develop)
- [Source Documentation](#source-documentation)
- [Special Rules in Shogi](#special-rules-in-shogi)

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

## Source Documentation

Building documentation for the source code is possible, although a convenient
CLI doesn't seem to exist at time of writing. Additionally, only public
functions/constants (those marked with the `pub` keyword) are shown.

Nonetheless, to build documentation for a particular module (say
`source/sdl.zig`), run the following bash command from the project root
directory, and then open up `docs/index.html` in your browser. This will show
docs for all publicly exposed functions, types, etc.

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

## Special Rules in Shogi

The basic rules of Shogi are easy to pick up. However, finding clear and
unambiguous English language explanations of the more complex rules can be more
difficult. So, for those curious about the finer points of these more complex
rules (e.g., how *exactly* does the repetition rule work, and in what ways is
perpetual check different in Shogi than in Chess?), here are the details.

For a more official reference, one may consult the [FESA rules][fesa-rules]
(these also contain details specific to over-the-board play).

### Promotion

A piece can be promoted when moving *out* of the promotion zone (the back three
ranks), as long it started *from* a square in the promotion zone.

Sometimes when moving a piece, that piece MUST be promoted. This only applies
to pawns (歩兵), knights (桂馬), and lances (香車) - pieces which can only move
forward, and so face the risk of becoming 'dead' pieces which are unable to
ever move again. Specifically:

- A pawn or lance moved to the last rank must promote.
- A knight moved to either of the last two ranks must promote.

### Drops

There are a few rules/restrictions on when you can drop a piece:

- A piece is always dropped un-promoted, even if dropped in the promotion zone.
- You cannot drop pawns/lances on the last rank, nor knights on the last two
  ranks (as they'd have no legal moves and be dead pieces).
- You cannot drop a pawn in a way that results in you having two un-promoted
  pawns on the same file. In over-the-board Shogi, this is probably the most
  commonly played illegal move and results in an instant loss. (However, it is
  okay to drop a pawn on the same file as any number of promoted pawns.)
- You cannot checkmate the opponent by dropping a pawn. (You *can* check them
  by dropping a pawn, as long as it is not an immediate mate. You can also
  checkmate the opponent by dropping any other piece.)

### Ending the Game

#### Repetition

Much like in Chess, a game can end due to a repetition of moves, although it is
much less common due to pieces never going out of play. In summary, the rules
are essentially the same (it results in a draw) with one exception: if a player
causes repetition by perpetually checking the opponent's king, then that player
*loses* the game instead of the game being drawn.

In more detail - a repetition occurs if the same position on the board is
reached four times, and each of those times it was the same player's turn and
both players had the same pieces in hand. This doesn't have to be
consecutive - the same 'game state' could be reached on moves 30, 32, 36,
and 42 for example.

When a repetition occurs, as in Chess the game automatically ends in a draw.
However, if this repetition was reached by one player continuously checking
the opponents king from the first repetition to the last, then that player
loses the game. It is okay for *some* of the moves in the repetition sequence
to be checks, as long as not ALL of them are.

#### Stalemate

Stalemate occurs when a player has no legal moves available to them. In Shogi,
this results in a loss for the player who cannot move. This is different than
Chess, where this would result in a draw for both players.

[direnv]: https://direnv.net
[sdl2]: https://www.libsdl.org
[shogi]: https://en.wikipedia.org/wiki/Shogi
[zig]: https://ziglang.org
[fesa-rules]: https://fesashogi.eu/pdf/FESA%20rules.pdf
