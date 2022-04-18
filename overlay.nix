self: super:

let patchelfer = arch: interpreter: super.writeShellScriptBin
		"patchelf-${arch}"
		"${super.patchelf}/bin/patchelf --set-interpreter ${interpreter} \"$@\"";
	
in {
	go = super.go.overrideAttrs (old: {
		version = "1.18";
		src = builtins.fetchurl {
			url    = "https://golang.org/dl/go1.18.linux-amd64.tar.gz";
			sha256 = "0kr6h1ddaazibxfkmw7b7jqyqhskvzjyc2c4zr8b3kapizlphlp8";
		};
		doCheck = false;
		patches = [
			# cmd/go/internal/work: concurrent ccompile routines
			(builtins.fetchurl "https://github.com/diamondburned/go/commit/ec3e1c9471f170187b6a7c83ab0364253f895c28.patch")
			# cmd/cgo: concurrent file generation
			(builtins.fetchurl "https://github.com/diamondburned/go/commit/50e04befeca9ae63296a73c8d5d2870b904971b4.patch")
		];
	});
	gopls = self.buildGoModule rec {
		pname = "gopls";
		version = "0.8.3";

		src = super.fetchgit {
			rev = "gopls/v0.8.3";
			url = "https://go.googlesource.com/tools";
			sha256 = "15gk59np06hc0q7wajxwizn5v9fs404yfz951ggmnzr467lk95az";
		};

		modRoot = "gopls";
		vendorSha256 = "0n3alxm6bj4j8av0b6jnwd6zrsffiygpdflbg1lnws4w10ry59m7";

		doCheck = false;
		subPackages = [ "." ];
	};
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
