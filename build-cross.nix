self:

{
	pkgs,
	target ? null,
	targets ? [ "x86_64-linux" "aarch64-linux" ],
	overridePackageAttrs ? (old: {}),

	base,
	tags ? [],
	version ? "unknown",
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
		(o:
			let
				name = lib.concatStringsSep "" [
					base.pname "-" o.GOOS "-" o.GOARCH
					(if o.version != "" then "-" else "") o.version
				];
			in
			builtins.trace
				"build-cross: will make ${name}.tar.zst"
				"${name} ${o}")
		(outputs);

	buildInputs = with pkgs; [
		coreutils
		zstd
	];

	passthru = {
		builtOutputs = outputs;
	};
} ''
	mkdir -p $out

	IFS=$'\n' readarray pkgs <<< "$OUTPUTS"
	for pkg in "''${pkgs[@]}"; do
		if [[ "$pkg" == "" || "$pkg" == $'\n' ]]; then
			continue
		fi

		read -r name path <<< "$pkg"
		# Fix issue #3 permission too strict.
		tar --zstd -vchf "$out/$name.tar.zst" -C "$path" --mode "a+rwX" .
	done
''
