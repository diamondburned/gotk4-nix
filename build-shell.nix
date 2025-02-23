self:

{
  base ? {
    pname = "gotk4-dev-shell";
  },
  pkgs,
  shellHook ? "",
  buildInputs ? [ ],
  clangdPackages ? (
    pkgs: with pkgs; [
      gtk4
      glib
    ]
  ),
  go ? pkgs.go,
  gopls ? pkgs.gopls,
  gotools ? pkgs.gotools,
  ...
}@args':

let
  pkgs' = pkgs;
in

let
  pkgs = pkgs'.extend self.overlays.patchelf;

  inherit (pkgs.extend self.overlays.patchelf)
    patchelf-x86_64
    patchelf-aarch64
    ;

  lib = pkgs.lib;

  args = builtins.removeAttrs args' [
    "base"
    "pkgs"
    "shellHook"
    "buildInputs"
    "clangdPackages"
  ];

  baseBuildInputs = base.buildInputs or (_: [ ]);
  baseNativeBuildInputs = base.nativeBuildInputs or (_: [ ]);

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

  buildInputs' = lib.unique (
    (with pkgs; [
      pkg-config

      clangd
      clang-tools # for clang-format

      git
      patchelf-x86_64-linux
      patchelf-aarch64-linux
    ])
    ++ [
      go
      gopls
      gotools
    ]
    ++ (baseDependencies)
    ++ (buildInputs)
    ++ (baseBuildInputs pkgs)
    ++ (baseNativeBuildInputs pkgs)
  );

  # Workaround for the lack of wrapGAppsHook:
  # https://nixos.wiki/wiki/Development_environment_with_nix-shell
  gotk4-env =
    pkgs.runCommandLocal "gotk4-env"
      {
        buildInputs = buildInputs';
        nativeBuildInputs = buildInputs' ++ (with pkgs; [ wrapGAppsHook ]);
      }
      ''
        cat<<-'EOF' > ./dump
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
      for path in ${concatStringsSep " " (map (pkg: pkg.dev.outPath) (clangdPackages pkgs))}; do
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
    ''
  );

in
pkgs.mkShell (
  {
    name = "${base.pname}-nix-shell";

    buildInputs = buildInputs';

    shellHook =
      with pkgs.gnome;
      with pkgs;
      ''
        while read -r key value; do
          export $key=''${!key}''${!key:+:}$value
        done < ${gotk4-env}

        export XDG_DATA_DIRS=$XDG_DATA_DIRS:${hicolor-icon-theme}/share:${adwaita-icon-theme}/share
        export XDG_DATA_DIRS=$XDG_DATA_DIRS:$GSETTINGS_SCHEMAS_PATH

        ${shellHook}
      '';

    # For debugging stack traces.
    NIX_DEBUG_INFO_DIRS = lib.makeSearchPath "lib/debug" (
      map (pkg: if pkg ? "debug" then pkg.debug else pkg) baseDependencies
    );

    CGO_ENABLED = "1";

    # Use /tmp, since /run/user/1000 (XDG_RUNTIME_DIRECTORY) might be too small.
    # See https://github.com/NixOS/nix/issues/395.
    TMP = "/tmp";
    TMPDIR = "/tmp";

    passthru = {
      inherit baseDependencies;
    };
  }
  // args
)
