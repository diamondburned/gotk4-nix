self:

{
	pkgs,
	target ? null,
	targets ? [ "x86_64" "aarch64" ],
	overridePackageAttrs ? (old: {}),

	base,
	tags ? [],
	version ? null,
	usePatchedGo ? false,
}:

let
	inherit (self) inputs;
	lib = pkgs.lib;

	targets' =
		if target != null
		then
			if builtins.isList target
			then target
			else [ target ]
		else targets;

	outputs = map
		(target: (import ./build-cross-package.nix self {
			inherit pkgs base tags version usePatchedGo;
			targetSystem = target;
			setInterpreter = true;
		}).overrideAttrs overridePackageAttrs)
		(targets');
in

pkgs.runCommandLocal "${base.pname}-cross" {
	# OUTPUTS = <<EOF
	# drv-name drv-path
	# drv-name drv-path
	# EOF
	OUTPUTS = lib.concatMapStringsSep "\n"
		(output:
			builtins.trace
				"build-cross: will make ${output.name}.tar.zst"
				"${output.name} ${output.outPath}")
		(outputs);

	buildInputs = with pkgs; [
		coreutils
		zstd
	];

	passthru = {
		inherit outputs;
	};
} ''
	mkdir -p $out

	IFS=$'\n' readarray pkgs <<< "$src"

	for pkg in "''${pkgs[@]}"; do
		if [[ "$pkg" == "" || "$pkg" == $'\n' ]]; then
			continue
		fi

		read -r name path <<< "$pkg"
		# Fix issue #3 permission too strict.
		tar --zstd -vchf "$out/$name.tar.zst" -C "$path" --mode "a+rwX" .
	done
''
