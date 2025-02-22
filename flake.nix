{
  description = "gotk4 Nix utility flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
    gomod2nix.url = "github:nix-community/gomod2nix";
    gomod2nix.inputs.flake-utils.follows = "flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    {
      lib = {
        mkShell = import ./build-shell.nix self;
        mkSource = import ./build-source.nix self;
        mkPackage = import ./build-package.nix self;
        mkPackageCross = import ./build-cross.nix self;

        mkLib =
          { base, pkgs }:
          nixpkgs.lib.mapAttrs (name: fn: { ... }@args: fn (args // { inherit base pkgs; })) {
            inherit (self.lib)
              mkShell
              mkSource
              mkPackage
              mkPackageCross
              ;
          };
      };

      overlays = {
        patchelf = import ./overlay-patchelf.nix;
        patchedGo = import ./overlay-patched-go.nix;
      };
    }
    // (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          upload-artifacts = import ./upload-artifacts.nix {
            inherit pkgs;
          };
          inherit (pkgs.extend self.overlays.patchelf)
            patchelf-x86_64-linux
            patchelf-aarch64-linux
            ;
        };
      }
    ));
}
