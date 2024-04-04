self:

{
	base,
	pkgs,
	version ? "unknown",
	cleanSource ? false,
	overridePackageAttrs ? (old: {}),
}:

let
	name = "${base.pname}-source";

	package = (import ./build-package.nix self {
		inherit base pkgs version;
	}).overrideAttrs overridePackageAttrs;

	vendor =
		package.goModules or
		package.vendorEnv or
		(throw "no pkg.goModules or pkg.vendorEnv found in package");

	vendorDir = pkgs.linkFarm "${name}-vendor" [
		{
			name = "vendor";
			path = vendor;
		}
	];

	sourceDir = pkgs.symlinkJoin {
		name = "${name}-output";
		paths = [
			base.src
			vendorDir
		];
	};
in

pkgs.runCommandLocal "${name}-${version}" {
	buildInputs = with pkgs; [
		coreutils
		zstd
	];
	inherit sourceDir;
	tarballName = name;
	passthru.package = package;
} ''
	mkdir $out
	tar --zstd -vchf "$out/$tarballName.tar.zst" -C "$sourceDir" .
''
