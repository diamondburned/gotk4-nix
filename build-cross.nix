{
	base,
	pkgs ? import ./pkgs.nix { useFetched = true; },
	target ? "x86_64", # x86_64 or aarch64
	targets ? [ target ],
}@args':

let lib = pkgs.lib;
	args = builtins.removeAttrs args [
		"base" "pkgs" "target" "targets"
	];
	
	shellCopy = pkg: name: attr: sh: pkgs.runCommandLocal
		name
		({
			src = pkg.outPath;
			buildInputs = pkg.buildInputs;
		} // attr)
		''
			mkdir -p $out
			cp -rf $src/* $out/
			chmod -R +w $out
			${sh}
		'';

	wrapGApps = pkg: shellCopy pkg (pkg.name + "-nixos") {
		nativeBuildInputs = with pkgs; [
			wrapGAppsHook
		];
	} "";

	withPatchelf = patchelf: pkg: shellCopy pkg
		"${pkg.name}-${patchelf.name}" {}
		"${patchelf}/bin/${patchelf.name} $out/bin/*";

	output = name: packages: pkgs.runCommandLocal name {
		# Join the object of name to packages into a line-delimited list of strings.
		src = with lib; foldr
			(a: b: a + "\n" + b) ""
			(mapAttrsToList (name: pkg: "${name} ${pkg.outPath}") packages);
		buildInputs = with pkgs; [ coreutils ];
	} ''
		mkdir -p $out

		IFS=$'\n' readarray pkgs <<< "$src"

		for pkg in "''${pkgs[@]}"; {
			[[ "$pkg" == "" || "$pkg" == $'\n' ]] && continue

			read -r name path <<< "$pkg"
			tar -zcvf "$out/${base.pname}-$name.tar.gz" -C "$path/bin/" "${base.pname}"
		}
	'';

	basePkgs = {
		x86_64 = import ./cross-package.nix ({
			inherit base pkgs;
			GOOS        = "linux";
			GOARCH      = "amd64";
			system      = "x86_64-linux";
			crossSystem = "x86_64-unknown-linux-gnu";
		} // args);
		aarch64 = import ./cross-package.nix ({
			inherit base pkgs;
			GOOS        = "linux";
			GOARCH      = "arm64";
			system      = "aarch64-linux";
			crossSystem = "aarch64-unknown-linux-gnu";
		} // args);
	};

	patchelfer = {
		x86_64  = pkgs.patchelf-x86_64;
		aarch64 = pkgs.patchelf-aarch64;
	};

	outputs' = lib.forEach targets (target: {
		"linux-${target}" = withPatchelf patchelfer.${target} basePkgs.${target};
		"nixos-${target}" = wrapGApps basePkgs.${target};
	});

	outputs = lib.foldl (a: b: a // b) {} outputs';

in output "${base.pname}-cross" outputs
