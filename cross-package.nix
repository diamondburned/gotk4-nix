{ GOOS, GOARCH, crossSystem, system, base, pkgs }:

let goPkgs = pkgs;

	pkgsPath = pkgs.path;
	pkgsWith = attrs: import pkgsPath attrs;
	pkgsHost = pkgsWith {};

	ov' = {
		overlays = [ (import ./overlay.nix) ];
	};

	pkgsCross = pkgsWith (if (pkgsHost.hostPlatform.config == crossSystem)
		then ov' // {  }
		else ov' // { crossSystem.config = crossSystem; });

	pkgsTarget = pkgsWith (if (pkgsHost.system == system)
		then {  }
		else { system = system; });

	buildGoModule = goPkgs.callPackage "${pkgsPath}/pkgs/development/go-modules/generic" {
		go = goPkgs.go // { inherit GOOS GOARCH; };
		stdenv = pkgsCross.stdenv;
	};

	baseSubPackages = base.subPackages or [ "." ];
	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);
	
in buildGoModule {
	inherit (base) src version vendorSha256;

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
		pkgconfig
		git # for Go
	]);

	subPackages = [ baseSubPackages ];

	buildFlags = "-buildmode pie";
}
