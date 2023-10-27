self: super:

let
	lib = super.lib;
	sources = import ./nix/sources.nix {};
	nixpkgs = import sources.nixpkgs {};

	gotk4-nix = super.__gotk4-nix;
	go_1_20 = super.go_1_20 or nixpkgs.go_1_20;

in {
	inherit go_1_20;

	go =
		if gotk4-nix.usePatchedGo then
			lib.warn "Using patched Go. Builds may be unstable and unreproducible. Only use this for development."
				go_1_20.overrideAttrs (old: {
					version = "${old.version}-cgo-parallel";
					patches = (old.patches or []) ++ [
						# cmd/go/internal/work: concurrent ccompile routines
						(builtins.fetchurl "https://github.com/diamondburned/go/commit/22f7e1a0a279ff29a6b07bf3002376da12113b58.patch")
						# cmd/cgo: concurrent file generation
						(builtins.fetchurl "https://github.com/diamondburned/go/commit/f80609cba09a92b8deec039f424813fc366b592b.patch")
						# cmd/cgo: fix gofmtBuf race condition
						(builtins.fetchurl "https://github.com/diamondburned/go/commit/d56410eeaf311a898f396526d69438ea361f2e52.patch")
					];
					doCheck = false;
				})
		else
			super.go;

	buildGoModule = super.buildGoModule.override {
		inherit (self) go;
	};

	gotools = super.gotools; # TODO

	dominikh = {
		gotools = self.buildGoModule {
			pname = "dominikh-go-tools";
			version = "0.3.0";

			src = super.fetchFromGitHub {
				owner  = "dominikh";
				repo   = "go-tools";
				rev    = "d7e217c1ff411395475b2971c0824e1e7cc1af98";
				sha256 = "0zfdx4yvqvkbrsfd9ca24kys5dm1nk70jwsyx2irr17z4lvmh8qv";
			};

			vendorSha256 = "0vcv0vmql2fbbp2nbxlbpn1siq541a8vr3vf1yidsl6hc66lvsv8";

			doCheck = false;
			subPackages = [ "cmd/staticcheck" ];
		};
	};

	patchelfer = arch: interpreter: super.writeShellScriptBin
		"patchelf-${arch}"
		"${super.patchelf}/bin/patchelf --set-interpreter ${interpreter} \"$@\"";
	# See https://sourceware.org/glibc/wiki/ABIList.
	patchelf-x86_64  = self.patchelfer "x86_64"  "/lib64/ld-linux-x86-64.so.2";
	patchelf-aarch64 = self.patchelfer "aarch64" "/lib/ld-linux-aarch64.so.1";

	webp-pixbuf-loader = super.callPackage ./packages/webp-pixbuf-loader.nix {};

	# CAUTION, for when I return: uncommenting these will trigger rebuilding a lot of Rust
	# dependencies, which will take forever! Don't do it!

	# gtk4 = (super.gtk4.override {
	# 	meson = super.meson_0_60;
	# }).overrideAttrs (old: {
	# 	version = "4.5.1";
	# 	src = super.fetchFromGitLab {
	# 		domain = "gitlab.gnome.org";
	# 		owner  = "GNOME";
	# 		repo   = "gtk";
	# 		rev    = "28f0e2eb";
	# 		sha256 = "1l7a8mdnfn54n30y2ii3x8c5zs0nm5n1c90wbdz1iv8d5hqx0f16";
	# 	};
	# 	buildInputs = old.buildInputs ++ (with super; [ xorg.libXdamage ]);
	# });
	# pango = super.pango.overrideAttrs (old: {
	# 	version = "1.49.4";
	# 	src = super.fetchFromGitLab {
	# 		domain = "gitlab.gnome.org";
	# 		owner  = "GNOME";
	# 		repo   = "pango";
	# 		# v1.49.4
	# 		rev    = "24ca0e22b8038eba7c558eb19f593dfc4892aa55";
	# 		sha256 = "1z8bdy5p1v5vl4kn0rkl80cyw916vxxf7r405jrfkm6zlarc4338";
	# 	};
	# 	buildInputs = old.buildInputs ++ (with super; [ json-glib ]);
	# });
}
