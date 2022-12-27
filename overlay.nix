self: super:

let patchelfer = arch: interpreter: super.writeShellScriptBin
		"patchelf-${arch}"
		"${super.patchelf}/bin/patchelf --set-interpreter ${interpreter} \"$@\"";

	lib = super.lib;

	go119 = super.go_1_19 or (super.go.overrideAttrs (old: {
		version = "1.19.2";
		src = builtins.fetchurl {
			url    = "https://golang.org/dl/go1.19.2.linux-amd64.tar.gz";
			sha256 = "1dpfny77vzz34zr71py2v3m50h5vm36ilijs0mzdsw34zrs5m32y";
		};
		doCheck = false;
	}));

in {
	go = super.go_1_19.overrideAttrs (old: {
		patches = (old.patches or []) ++ [
			# cmd/go/internal/work: concurrent ccompile routines
			(builtins.fetchurl "https://github.com/diamondburned/go/commit/904669ff7906122c03ee67160e094115ebb1f527.patch")
			# cmd/cgo: concurrent file generation
			(builtins.fetchurl "https://github.com/diamondburned/go/commit/0ee3ff87e3acd89f13df68a4143517b29d2d7f04.patch")
		];
	});
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

	# See https://sourceware.org/glibc/wiki/ABIList.
	patchelf-x86_64  = patchelfer "x86_64"  "/lib64/ld-linux-x86-64.so.2";
	patchelf-aarch64 = patchelfer "aarch64" "/lib/ld-linux-aarch64.so.1";

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
