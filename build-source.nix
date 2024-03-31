self:

{
	base,
	pkgs,
	version ? null,
	overridePackageAttrs ? (old: {}),
}:

let
	version' = self.lib.optionalVersion base version;
	name = "${base.pname}-source-${version'}";

	src = builtins.filterSource
		(path: type:
			# Only accept files and directories
			(type == "directory" || type == "regular") &&
			# Filter out hidden files and directories
			(!pkgs.lib.hasPrefix "." (builtins.baseNameOf path))
		)
		base.src;

	package = (import ./package.nix {
		inherit base pkgs version;
	}).overrideAttrs overridePackageAttrs;

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
in
	
pkgs.runCommandLocal name {
	buildInputs = with pkgs; [
		coreutils
		zstd
	];
} ''
	mkdir $out
	tar --zstd -vchf "$out/${name}.tar.zst" -C "${output}" .
''
