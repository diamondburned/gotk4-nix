{ GOOS, GOARCH, crossSystem, system, base, pkgs, ... }@args':

let args = builtins.removeAttrs args' [ "GOOS" "GOARCH" "crossSystem" "system" "base" "pkgs" ];

	goPkgs = pkgs;

	pkgsPath = pkgs.path;
	pkgsWith = attrs: import pkgsPath attrs;
	pkgsHost = pkgsWith {};

	sources = import ./nix/sources.nix;
	ov' = {
		overlays = [
			(import ./overlay.nix)
			(import "${sources.gomod2nix}/overlay.nix")
		];
	};

	pkgsCross = pkgsWith (if (pkgsHost.hostPlatform.config == crossSystem)
		then ov' // {  }
		else ov' // { crossSystem.config = crossSystem; });

	pkgsTarget = pkgsWith (if (pkgsHost.system == system)
		then {  }
		else { system = system; });

	go = goPkgs.go // {
		inherit GOOS GOARCH;
	};

	buildGoModule = goPkgs.callPackage "${pkgsPath}/pkgs/development/go-modules/generic" {
		inherit go;
		stdenv = pkgsCross.stdenv;
	};

	gomod2nix_builder = goPkgs.callPackage "${sources.gomod2nix}/builder" {
		stdenv = pkgsCross.stdenv;
	};
	buildGoPackage = gomod2nix_builder.buildGoApplication;

	baseSubPackages = base.subPackages or [ "." ];
	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);

	builder = if (base.modules != null)
		then buildGoPackage
		else buildGoModule;
	
in builder ({
	inherit (base) src version modules vendorSha256;
	inherit go;

	CGO_ENABLED = "1";

	pname = base.pname + "-${GOOS}-${GOARCH}";

	buildInputs = (baseBuildInputs pkgsTarget) ++ (with pkgsTarget; [
		gtk4
		glib
		graphene
		gdk-pixbuf
		gobject-introspection
		hicolor-icon-theme
	]);

	nativeBuildInputs = (baseNativeBuildInputs goPkgs) ++ (with goPkgs; [
		pkg-config
		git # for Go
	]);

	subPackages = [ baseSubPackages ];

	buildFlags = "-buildmode pie";

	doCheck = false;
} // args)
