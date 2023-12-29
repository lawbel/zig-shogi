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

  };

  outputs = { self, nixpkgs, zig, flake-utils, ... }:
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
            nativeBuildInputs = [ pkgs.zigpkgs.master ];
          };
        }
      );
}
