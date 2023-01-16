{
	pkgs,
	base, # see package-base.nix.tmpl

	# Optionals.
	buildPkgs ? import ./pkgs.nix {}, # only for overriding
	goPkgs ? buildPkgs,
	lib ? pkgs.lib,
	rev ? null,

	...
}@args':

let args = builtins.removeAttrs args' [ "pkgs" "lib" "base" ];
	util = import ./util.nix pkgs;

	baseSubPackages = base.subPackages or [ "." ];
	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);

	builder = if (base ? modules)
		then goPkgs.buildGoApplication
		else goPkgs.buildGoModule;

in builder (rec {
	inherit (base) src;
	inherit (goPkgs) go;

	name = "${base.pname}-${version}";
	version = util.optionalVersion base rev;

	modules = if base ? modules then base.modules else null;
	vendorSha256 = if base ? vendorSha256 then base.vendorSha256 else null;

	buildInputs = baseBuildInputs buildPkgs ++ (with buildPkgs; [
		gtk4
		glib
		librsvg
		gdk-pixbuf
		gobject-introspection
		hicolor-icon-theme
	]);

	nativeBuildInputs = baseNativeBuildInputs pkgs ++ (with pkgs; [
		wrapGAppsHook
		pkg-config
		git # for Go
	]);

	subPackages = baseSubPackages;

	buildFlags = "-buildmode pie";

	preFixup = with base.files; ''
		mkdir -p $out/share/icons/hicolor/256x256/apps/ $out/share/applications/
		cp ${desktop.path} $out/share/applications/${desktop.name}
		cp ${logo.path} $out/share/icons/hicolor/256x256/apps/${logo.name}
	'';

	doCheck = false;
} // args)
