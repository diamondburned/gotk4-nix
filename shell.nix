{
	base ? {
		pname = "gotk4-unnamed";
	},
	pkgs ? import ./pkgs.nix {},
	shellHook ? "",
	buildInputs ? (pkgs: []),
	pixbufModules ? (pkgs: with pkgs;
		[ librsvg ]
		++ (if pkgs ? "webp-pixbuf-loader" then [ webp-pixbuf-loader ] else [])
	),
	clangdPackages ? (pkgs: with pkgs; [ gtk4 glib ]),
	...
}@args':

let
	src = import ./src.nix;
	lib = pkgs.lib;

	args = builtins.removeAttrs args' [
		"base"
		"pkgs"
		"buildInputs"
		"clangdPackages"
	];

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

	baseDependencies = with pkgs; [
		# Bare minimum required.
		atk
		gtk3
		gtk4
		glib
		graphene
		gdk-pixbuf
		gobject-introspection
		librsvg
	];

	buildInputs' = lib.unique ((with pkgs; [
		pkg-config

		go
		gopls
		gotools
		clangd

		git

		# Tools
		minitime
		generate
		build

		patchelf-x86_64
		patchelf-aarch64
	])
	++ (baseDependencies)
	++ (buildInputs pkgs)
	++ (baseBuildInputs pkgs)
	++ (baseNativeBuildInputs pkgs));

	# Workaround for the lack of wrapGAppsHook:
	# https://nixos.wiki/wiki/Development_environment_with_nix-shell
	gotk4-env =  pkgs.runCommandLocal "gotk4-env" {
		buildInputs = buildInputs';
		nativeBuildInputs = buildInputs' ++ (with pkgs; [ wrapGAppsHook ]);
	} ''
		cat<<'EOF' > ./dump
#!${pkgs.runtimeShell}
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

	clangd = pkgs.writeShellScriptBin "clangd" (
		with pkgs.gnome;
		with pkgs;
		with lib;
		''
			for path in ${concatStringsSep " " (map (pkg: pkg.outPath) (clangdPackages pkgs))}; do
				for file in $path/lib/pkgconfig/*.pc; do
					[[ ! -f $file ]] && continue
					packages+=( $(basename $file .pc) )
				done
			done

			for pkg in ''${packages[@]}; do
				cpath=$(pkg-config $pkg --cflags-only-I | sed 's/ -I/:/g' | sed 's/^-I//')
				if [[ $cpath == "" ]]; then
					continue
				fi

				if [[ -z $CPATH ]]; then
					export CPATH=$cpath
				else
					export CPATH=$CPATH:$cpath
				fi
			done

			exec ${pkgs.clang-tools}/bin/clangd "$@"
		'');

in pkgs.mkShell ({
	name = "${base.pname}-nix-shell";

	buildInputs = buildInputs';

	shellHook = with pkgs.gnome; with pkgs; ''
		while read -r key value; do
			export $key=''${!key}''${!key:+:}$value
		done < ${gotk4-env}

		export XDG_DATA_DIRS=$XDG_DATA_DIRS:${hicolor-icon-theme}/share:${adwaita-icon-theme}/share
		export XDG_DATA_DIRS=$XDG_DATA_DIRS:$GSETTINGS_SCHEMAS_PATH
		export GDK_PIXBUF_MODULE_FILE=${
			lib.makeSearchPath
				"lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
				(pixbufModules pkgs)}

		${shellHook}
	'';

	# For debugging stack traces.
	NIX_DEBUG_INFO_DIRS = lib.makeSearchPath
		"lib/debug"
		(map
			(pkg: if pkg ? "debug" then pkg.debug else pkg)
			baseDependencies);

	CGO_ENABLED  = "1";

	# Use /tmp, since /run/user/1000 (XDG_RUNTIME_DIRECTORY) might be too small.
	# See https://github.com/NixOS/nix/issues/395.
	TMP    = "/tmp";
	TMPDIR = "/tmp";
} // args)
