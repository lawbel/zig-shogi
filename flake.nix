{
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
      zig-pkgs = final: prev: {
        zigpkgs = zig.packages.${prev.system};
      };
      overlays = [ zig-pkgs ];
      systems = builtins.attrNames zig.packages;
      name = "shogi";
    in
      flake-utils.lib.eachSystem systems (system:
        let
          pkgs = import nixpkgs { inherit overlays system; };
        in {
          packages.default = pkgs.stdenv.mkDerivation {
            inherit name;
            src = ./.;
            buildInputs = [
              pkgs.zigpkgs.master
              pkgs.glibc
              pkgs.SDL2
              pkgs.SDL2.dev
              pkgs.pkg-config
            ];
            buildPhase = ''
              # By default zig will check a global cache for build artefacts.
              # We must disable this behaviour to get a pure build environment,
              # which we can do by simply re-directing that cache to an empty
              # one we create locally.
              mkdir ./empty-cache

              # TODO: fix this, it is currently broken
              zig build \
                --global-cache-dir ./empty-cache \
                -Doptimize=ReleaseFast
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp zig-out/bin/${name} $out/bin
            '';
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              pkgs.zigpkgs.master
              zls.packages.${system}.zls
              pkgs.glibc
              pkgs.SDL2
              pkgs.SDL2.dev
              pkgs.pkg-config
            ];
          };
        }
      );
}
