{
	base,
	pkgs ? import <nixpkgs> {},
}:

import ./package.nix {
	inherit pkgs base;
	lib = pkgs.lib;
}
