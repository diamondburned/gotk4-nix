{
	base,
	pkgs ? import ./pkgs.nix {},
	buildInputs ? (pkgs: []),
}:

let src = import ./src.nix;
	lib = pkgs.lib;

	# minitime is a mini-output time wrapper.
	minitime = pkgs.writeShellScriptBin "minitime"
		"command time --format $'%C -> %es\\n' \"$@\"";

	generate = pkgs.writeShellScriptBin "generate"
		"go generate";

	build = pkgs.writeShellScriptBin "build" ''
		cd pkg
		go build -v ./...
	'';

	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);

in pkgs.mkShell {
	name = "${base.pname}-nix-shell";

	buildInputs = with pkgs; [
		# Bare minimum required.
		gtk4
		glib
		graphene
		gdk-pixbuf
		gobject-introspection
		pkgconfig

		gtk4.debug
		glib.debug

		# Always use patched Go, since it's much faster.
		go
		gopls
		gotools
		dominikh.gotools

		git

		# Tools
		minitime
		generate
		build

		patchelf-x86_64
		patchelf-aarch64
	]
	++ (buildInputs pkgs)
	++ (baseBuildInputs pkgs)
	++ (baseNativeBuildInputs pkgs);

	# Workaround for the lack of wrapGAppsHook:
	# https://nixos.wiki/wiki/Development_environment_with_nix-shell
	shellHook = with pkgs; with pkgs.gnome; ''
		export XDG_DATA_DIRS=$XDG_DATA_DIRS:${hicolor-icon-theme}/share:${adwaita-icon-theme}/share
		export XDG_DATA_DIRS=$XDG_DATA_DIRS:$GSETTINGS_SCHEMAS_PATH
	'';

	# For debugging stack traces.
	NIX_DEBUG_INFO_DIRS = ''${pkgs.gtk4.debug}/lib/debug:${pkgs.glib.debug}/lib/debug'';

	CGO_ENABLED  = "1";
	# CGO_CFLAGS   = "-g2 -O2";
	# CGO_CXXFLAGS = "-g2 -O2";
	# CGO_FFLAGS   = "-g2 -O2";
	# CGO_LDFLAGS  = "-g2 -O2";

	# Use /tmp, since /run/user/1000 (XDG_RUNTIME_DIRECTORY) might be too small.
	# See https://github.com/NixOS/nix/issues/395.
	TMP    = "/tmp";
	TMPDIR = "/tmp";
}
