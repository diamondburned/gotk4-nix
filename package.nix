{
	pkgs,
	base, # see package-base.nix.tmpl

	# Optionals.
	buildPkgs ? import ./pkgs.nix {}, # only for overriding
	goPkgs ? buildPkgs,
	version ? null,
	tags ? [],
}:

with pkgs.lib;
with builtins;
with import ./util.nix pkgs;

let
	baseSubPackages = base.subPackages or [ "." ];
	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);

	builder = if (base ? modules)
		then goPkgs.buildGoApplication
		else goPkgs.buildGoModule;

in builder {
	inherit (base) pname src;
	inherit (goPkgs) go;

	version =
		(optionalVersion base version) +
		(optionalString (tags != []) "-${concatStringsSep "+" tags}");

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

	preFixup =
		with base.files;
		optionalString (hasAttr base.files "desktop") ''
			mkdir -p $out/share/applications/
			cp ${desktop.path} $out/share/applications/${desktop.name}
		'' +
		optionalString (hasAttr base.files "logo") ''
			mkdir -p $out/share/icons/hicolor/256x256/apps/
			cp ${logo.path} $out/share/icons/hicolor/256x256/apps/${logo.name}
		'' +
		optionalString (hasAttr base.files "service") ''
			mkdir -p $out/share/dbus-1/services/
			cp ${service.path} $out/share/dbus-1/services/${service.name}
		'';

	doCheck = false;
}
