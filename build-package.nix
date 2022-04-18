{ base }:

let pkgs = import <nixpkgs> {};

in import ./package.nix {
	inherit pkgs base;
	lib = pkgs.lib;
}
