{
  description = "gotk4 Nix utility flake";

  inputs = {
		nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
		flake-utils.url = "github:numtide/flake-utils";
		flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
		gomod2nix.url = "github:nix-community/gomod2nix";
		gomod2nix.inputs.flake-utils.follows = "flake-utils";
  };

	outputs = { self, nixpkgs, flake-utils, ... }: {
		lib = {
			optionalVersion = base: version:
				if (version != null) then
					version
				else
					if (base ? version && base.version != null) then
						base.version
					else
						"unknown";

			mkShell = import ./build-shell.nix self;
			mkSource = import ./build-source.nix self;
			mkPackage = import ./build-package.nix self;
			mkPackageCross = import ./build-cross.nix self;
		};

		overlays = {
			patchelf = import ./overlay-patchelf.nix;
			patchedGo = import ./overlay-patched-go.nix;
		};
	} // (flake-utils.lib.eachDefaultSystem (system: {
		packages.upload-artifacts = import ./upload-artifacts.nix {
			pkgs = nixpkgs.legacyPackages.${system};
		};
	}));
}
