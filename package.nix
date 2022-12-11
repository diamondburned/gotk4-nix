{
	pkgs,
	base, # see package-base.nix.tmpl

	# Optionals.
	buildPkgs ? import ./pkgs.nix {}, # only for overriding
	goPkgs ? buildPkgs,
	lib ? pkgs.lib,

	...
}@args:

let baseSubPackages = base.subPackages or [ "." ];
	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);

in goPkgs.buildGoModule (args // {
	inherit (base) pname src version vendorSha256;

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

	preFixup = with base.files; ''
		mkdir -p $out/share/icons/hicolor/256x256/apps/ $out/share/applications/
		cp ${desktop.path} $out/share/applications/${desktop.name}
		cp ${logo.path} $out/share/icons/hicolor/256x256/apps/${logo.name}
	'';
})
