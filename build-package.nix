{
	base,
	pkgs ? import <nixpkgs> {},
	...
}@args:

import ./package.nix (args // {
	inherit pkgs base;
	lib = pkgs.lib;
})
