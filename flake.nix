{
  description = "The game Shogi, implemented in Zig with the help of SDL2.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-compat.follows = "flake-compat";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls = {
      url = "github:zigtools/zls";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-overlay.follows = "zig";
    };
  };

  outputs = { self, nixpkgs, zig, zls, flake-utils, ... }:
    let
      system = "x86_64-linux";
      name = "shogi";
      pkgs = import nixpkgs { inherit system; };

      commonInputs = [
        # zig
        zig.packages.${system}.master
        # C
        pkgs.glibc
        pkgs.pkg-config
        # SDL
        pkgs.SDL2
        pkgs.SDL2.dev
        pkgs.SDL2_image
        pkgs.SDL2_gfx
        pkgs.SDL2_ttf
      ];

    in {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        inherit name;
        src = ./.;
        buildInputs = commonInputs;

        buildPhase = ''
          # By default zig will check a global cache for build artefacts.
          # We must disable this behaviour to get a pure build environment,
          # which we can do by simply re-directing that cache to an empty
          # one we create locally.
          mkdir ./empty-cache

          # Nix outputs should be deterministic, so we set the seed to help
          # with that.
          zig build \
            --global-cache-dir ./empty-cache \
            --seed 12345 \
            -Doptimize=ReleaseFast
        '';

        installPhase = ''
          mkdir -p $out/bin

          # This changes the 'dynamic loader' / 'ELF interpreter' of the
          # resulting binary from musl to glibc. Without this, the output will
          # not work. I would rather give zig some options to fix the
          # underlying linker issue, but for now this solves the problem and
          # makes this into a complete working build.
          patchelf \
            --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
            --output $out/bin/${name} \
            zig-out/bin/${name}
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        nativeBuildInputs = commonInputs ++ [ zls.packages.${system}.zls ];
      };
    };
}
