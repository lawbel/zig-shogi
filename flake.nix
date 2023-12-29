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
    in
      flake-utils.lib.eachSystem systems (system:
        let
          pkgs = import nixpkgs { inherit overlays system; };
        in {
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              pkgs.zigpkgs.master
              zls.packages.${system}.zls
            ];
          };
        }
      );
}
