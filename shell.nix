{
	base ? {
		pname = "gotk4-unnamed";
		buildInputs = (_: []);
		nativeBuildInputs = (_: []);
	},
	pkgs ? import ./pkgs.nix {},
	buildInputs ? (pkgs: []),
	...
}@args':

let
	src = import ./src.nix;
	lib = pkgs.lib;

	args = builtins.removeAttrs args' [ "base" "pkgs" "buildInputs" ];

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

	# For backwards compatibility.
	gtk3 = pkgs.gtk3 or pkgs.gnome3.gtk;

	buildInputs'' = with pkgs; [
		# Bare minimum required.
		atk
		gtk3
		gtk4
		glib
		graphene
		gdk-pixbuf
		gobject-introspection
		pkg-config
		librsvg
		# webp-pixbuf-loader

		gtk4.debug
		glib.debug

		# Always use patched Go, since it's much faster.
		go
		gopls
		gotools

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

	buildInputs' = pkgs.lib.unique buildInputs'';

	# Workaround for the lack of wrapGAppsHook:
	# https://nixos.wiki/wiki/Development_environment_with_nix-shell
	gotk4-env =  pkgs.runCommandLocal "gotk4-env" {
		buildInputs = buildInputs';
		nativeBuildInputs = buildInputs' ++ (with pkgs; [ wrapGAppsHook ]);
	} ''
		cat<<'EOF' > ./dump
#!${pkgs.bash}/bin/bash
envs=(
	XDG_DATA_DIRS
	GSETTINGS_SCHEMAS_PATH
)
for env in "''${envs[@]}"; {
	printf "%s %q\n" "$env" "''${!env}"
}
EOF
		chmod +x ./dump

		gappsWrapperArgsHook
		wrapGApp ./dump

		./dump > $out
	'';

in pkgs.mkShell (rec {
	name = "${base.pname}-nix-shell";

	buildInputs = buildInputs';

	cPackages = [
		"gtk4"
		"gtk+-3.0"
	];

	shellHook = with pkgs.gnome; with pkgs; ''
		while read -r key value; do
			export $key=''${!key}''${!key:+:}$value
		done < ${gotk4-env}

		export GDK_PIXBUF_MODULE_FILE='${librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache'
		export XDG_DATA_DIRS=$XDG_DATA_DIRS:${hicolor-icon-theme}/share:${adwaita-icon-theme}/share
		export XDG_DATA_DIRS=$XDG_DATA_DIRS:$GSETTINGS_SCHEMAS_PATH

		for pkg in ${pkgs.lib.concatStringsSep " " cPackages}; do
			__cpath=$(pkg-config $pkg --cflags-only-I | sed 's/ -I/:/g' | sed 's/^-I//')
			if [[ $__cpath == "" ]]; then
				continue
			fi

			if [[ -z $CPATH ]]; then
				export CPATH=$__cpath
			else
				export CPATH=$CPATH:$__cpath
			fi
		done
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
} // args)
