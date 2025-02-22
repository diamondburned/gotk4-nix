self:

{
  base,
  pkgs,
  tags ? [ ],
  version ? "unknown",
  overridePackageAttrs ? (old: { }),
  go ? pkgs.go,
}:

let
  inherit (self) inputs;

  baseSubPackages = base.subPackages or [ "." ];
  baseBuildInputs = base.buildInputs or (_: [ ]);
  baseNativeBuildInputs = base.nativeBuildInputs or (_: [ ]);

  builderPkgs = pkgs.extend inputs.gomod2nix.overlays.default;
  builder = if (base ? modules) then builderPkgs.buildGoApplication else builderPkgs.buildGoModule;
in

(builder {
  inherit (base) pname src;
  inherit go;

  version = with pkgs.lib; version + (optionalString (tags != [ ]) "-${concatStringsSep "+" tags}");

  modules = if base ? modules then base.modules else null;
  vendorSha256 = if base ? vendorSha256 then base.vendorSha256 else null;

  buildInputs =
    baseBuildInputs pkgs
    ++ (with pkgs; [
      gtk4
      glib
      librsvg
      gdk-pixbuf
      gobject-introspection
      hicolor-icon-theme
    ]);

  nativeBuildInputs =
    baseNativeBuildInputs pkgs
    ++ (with pkgs; [
      wrapGAppsHook
      pkg-config
      git # for Go
    ]);

  subPackages = baseSubPackages;

  hardeningEnable = [ "pie" ];

  preFixup =
    with pkgs.lib;
    with builtins;
    with base.files;
    optionalString (hasAttr "desktop" base.files) ''
      			mkdir -p $out/share/applications/
      			cp ${desktop.path} $out/share/applications/${desktop.name}
      		''
    + optionalString (hasAttr "logo" base.files) ''
      			mkdir -p $out/share/icons/hicolor/256x256/apps/
      			cp ${logo.path} $out/share/icons/hicolor/256x256/apps/${logo.name}
      		''
    + optionalString (hasAttr "service" base.files) ''
      			mkdir -p $out/share/dbus-1/services/
      			cp ${service.path} $out/share/dbus-1/services/${service.name}
      		''
    + optionalString (hasAttr "icons" base.files) ''
      			mkdir -p $out/share/icons/
      			cp -r ${icons.path}/* $out/share/icons/
      		'';

  doCheck = false;
}).overrideAttrs
  overridePackageAttrs
