self:

{
	pkgs, # host package set
	targetSystem, # the system that the package is built for
	setInterpreter ? true, # whether to use patchelf to reset the ELF interpreter

	base,
	tags ? [],
	version ? "unknown",
	usePatchedGo ? false,
}:

let
	inherit (self) inputs;
	lib = pkgs.lib;

	overlays =
		[
			self.inputs.gomod2nix.overlays.default
			self.overlays.patchelf
		]
		++ (if usePatchedGo then [ self.overlays.patchedGo ] else []);

	# pkgsTarget is the set of packages that are meant to run on the target system.
	# Packages within this set can only be executed on that target system.
	pkgsTarget = import pkgs.path {
		inherit overlays;
		system = targetSystem;
	};

	# pkgsCross is the set of packages that run on the host but are intended to cross-compile
	# for the specified cross-system. Packages within this set can run on the host, but extra
	# packages are included for building for target.
	pkgsCross = import pkgs.path {
		inherit overlays;
		inherit (pkgs) system;
		crossSystem.config = pkgsTarget.stdenv.targetPlatform.config;
 	};

	patchelf =
		let
			name = "patchelf-${targetSystem}";
		in
			if builtins.hasAttr name pkgsCross
			then builtins.getAttr name pkgsCross
			else throw "no supported patchelf for target ${targetSystem}";

	GOOS = pkgsTarget.stdenv.targetPlatform.parsed.kernel.name;
	GOARCH =
		let
			# Taken from
			# https://github.com/NixOS/nixpkgs/blob/7d55d624b1df7e097a96454cc37da7d17bff5ec8/pkgs/development/compilers/go/1.21.nix#L25.
			goarch = {
				"aarch64" = "arm64";
				"arm" = "arm";
				"armv5tel" = "arm";
				"armv6l" = "arm";
				"armv7l" = "arm";
				"i686" = "386";
				"mips" = "mips";
				"mips64el" = "mips64le";
				"mipsel" = "mipsle";
				"powerpc64le" = "ppc64le";
				"riscv64" = "riscv64";
				"s390x" = "s390x";
				"x86_64" = "amd64";
			};
			system = pkgsTarget.stdenv.targetPlatform.parsed.cpu.name;
		in
		goarch.${system} or (throw "gotk4-nix: unsupported system for Go: ${system}");

	# Build using the host's Go toolchain.
	# Go is already capable of cross-compiling, we just need to set the right environment variables.
	go = pkgs.go // {
		inherit GOOS GOARCH;
	};

	buildGoModule = pkgs.callPackage "${pkgs.path}/pkgs/development/go-modules/generic" {
		inherit go;
		inherit (pkgsCross) stdenv;
	};

	buildGoApplication = (pkgs.callPackage "${inputs.gomod2nix}/builder" {
		inherit (pkgsCross) stdenv;
		gomod2nix = inputs.gomod2nix.packages.${pkgs.system}.default;
	}).buildGoApplication;

	builder = if (base ? modules)
		then buildGoApplication
		else buildGoModule;

	baseSubPackages = base.subPackages or [ "." ];
	baseBuildInputs = base.buildInputs or (_: []);
	baseNativeBuildInputs = base.nativeBuildInputs or (_: []);
in

builder {
	inherit go tags;
	inherit (base) pname src;

	version =
		with lib;
		version + (optionalString (tags != []) "-${concatStringsSep "+" tags}");

	CGO_ENABLED = "1";

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

	nativeBuildInputs = (baseNativeBuildInputs pkgs) ++ (with pkgs; [
		pkg-config
		git # for Go
	]);

	subPackages = [ baseSubPackages ];

	hardeningEnable = [ "pie" ];

	preFixup =
		with lib;
		with builtins;
		with base.files;
		optionalString (hasAttr "desktop" base.files) ''
			mkdir -p $out/share/applications/
			cp ${desktop.path} $out/share/applications/${desktop.name}
		'' +
		optionalString (hasAttr "logo" base.files) ''
			mkdir -p $out/share/icons/hicolor/256x256/apps/
			cp ${logo.path} $out/share/icons/hicolor/256x256/apps/${logo.name}
		'' +
		optionalString (hasAttr "service" base.files) ''
			mkdir -p $out/share/dbus-1/services/
			cp ${service.path} $out/share/dbus-1/services/${service.name}
		'';

	postInstall = lib.optionalString setInterpreter ''
		${lib.getExe patchelf} $out/bin/*
	'';

	doCheck = false;
}
