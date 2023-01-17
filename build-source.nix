{
	base,
	pkgs ? import ./pkgs.nix { useFetched = true; },
	version ? null,
	pkgOpts ? {},
}:

let args = builtins.removeAttrs args [ "pkgs" "base" "rev" ];
	util = import ./util.nix pkgs;

	version' = util.optionalVersion base version;
	name = "${base.pname}-${version'}-source";

	src = builtins.filterSource
		(path: type:
			# Only accept files and directories
			(type == "directory" || type == "regular") &&
			# Filter out hidden files and directories
			(! pkgs.lib.hasPrefix "." (builtins.baseNameOf path))
		)
		base.src;

	package = import ./package.nix (pkgOpts // {
		inherit base pkgs version;
	});

	vendor = pkgs.linkFarm "${name}-vendor" [
		{ name = "vendor"; path = package.vendorEnv; }
	];

	output = pkgs.symlinkJoin {
		name = "${name}-output";
		paths = [
			src
			vendor
		];
	};

in pkgs.runCommandLocal name {} ''
	mkdir $out
	tar -zcvhf "$out/${name}.tar.gz" -C "${output}" .
''
