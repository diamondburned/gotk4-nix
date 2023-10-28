{
	systemChannel ? <nixpkgs>,
	sourceNixpkgs ? <nixpkgs>,
	useFetched ? false,
	usePatchedGo ? false,
	overlays ? [],
}:

let src = import ./nix/sources.nix;
	ov' = [
		(self: super: {
			__gotk4-nix = {
				inherit usePatchedGo;
			};
		})
		(import ./overlay.nix)
		(import "${src.gomod2nix}/overlay.nix")
	];

	systemPkgs = import systemChannel {
		overlays = ov' ++ overlays;
	};
	lib = systemPkgs.lib;

	pkgs = import sourceNixpkgs {
		overlays = ov' ++ overlays;
	};

in
	if (!useFetched && (systemPkgs.gtk4 or null) != null && lib.versionAtLeast systemPkgs.gtk4.version "4.4.0")
	# Prefer the system's Nixpkgs if it's new enough.
	then systemPkgs
	# Else, fetch our own.
	else pkgs
