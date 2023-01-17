{
	crossSystem, system, base, pkgs,
	GOOS, GOARCH,
	tags ? [], version ? null,
	...
}@args':

with pkgs.lib;
with builtins;

let args = builtins.removeAttrs args' [
		"crossSystem" "system" "base" "pkgs"
		"tags" "version"
	];
	util = import ./util.nix pkgs;

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
	buildGoApplication = gomod2nix_builder.buildGoApplication;

	baseSubPackages = base.subPackages or [ "." ];
	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);

	builder = if (base ? modules)
		then buildGoApplication
		else buildGoModule;
	
in builder ({
	inherit (base) pname src;
	inherit go tags;

	CGO_ENABLED = "1";

	version = "${util.optionalVersion base version}" +
		"-${GOOS}-${GOARCH}" +
		(optionalString (tags != []) "-${concatStringsSep "+" tags}");

	modules = if (base ? modules) then base.modules else null;
	vendorSha256 = if (base ? vendorSha256) then base.vendorSha256 else null;

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

	preFixup = with base.files; ''
		mkdir -p $out/share/icons/hicolor/256x256/apps/ $out/share/applications/
		cp ${desktop.path} $out/share/applications/${desktop.name}
		cp ${logo.path} $out/share/icons/hicolor/256x256/apps/${logo.name}
	'';

	doCheck = false;
} // args)
