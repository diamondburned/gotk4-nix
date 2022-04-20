{
	systemChannel ? <nixpkgs>,
	sourceNixpkgs ? (import ./src.nix).nixpkgs,
	useFetched ? false,
}:

let systemPkgs = import systemChannel {
		overlays = [ (import ./overlay.nix) ];
	};
	lib = systemPkgs.lib;

	pkgs = import sourceNixpkgs {
		overlays = [ (import ./overlay.nix) ];
	};

in
	if (!useFetched && (systemPkgs.gtk4 or null) != null && lib.versionAtLeast systemPkgs.gtk4.version "4.4.0")
	# Prefer the system's Nixpkgs if it's new enough.
	then systemPkgs
	# Else, fetch our own.
	else pkgs
