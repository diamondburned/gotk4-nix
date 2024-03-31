final: prev:

let
	lib = prev.lib;
in 
	
lib.warn
"gotk4-nix: using patched Go 1.20!! Builds *WILL* be unstable and unreproducible. Only use this" +
"strictly for development purposes."
	
{
	go_1_20 = prev.go_1_20.overrideAttrs (old: {
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
	});

	go = final.go_1_20;
	buildGoModule = prev.buildGoModule.override {
		inherit (final) go;
	};
}
