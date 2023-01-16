{
	base,
	pkgs ? import ./pkgs.nix { useFetched = true; },
	tags ? [],
	target ? null,
	targets ? [ "x86_64" "aarch64" ],
	...
}@args':

let lib = pkgs.lib;
	args = builtins.removeAttrs args' [
		"base" "pkgs" "tags" "target" "targets"
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
			tar -zcvhf "$out/${base.pname}-$name.tar.gz" -C "$path" .
		}
	'';

	linuxPkgs = {
		x86_64 = import ./package-cross.nix ({
			inherit base pkgs tags;
			GOOS        = "linux";
			GOARCH      = "amd64";
			system      = "x86_64-linux";
			crossSystem = "x86_64-unknown-linux-gnu";
		} // args);
		aarch64 = import ./package-cross.nix ({
			inherit base pkgs tags;
			GOOS        = "linux";
			GOARCH      = "arm64";
			system      = "aarch64-linux";
			crossSystem = "aarch64-unknown-linux-gnu";
		} // args);
		source = import ./package-cross ({
			inherit base pkgs;
		} // args);
	};

	patchelfer = {
		x86_64  = pkgs.patchelf-x86_64;
		aarch64 = pkgs.patchelf-aarch64;
	};

	targets' =
		if target != null
		then
			if builtins.isList target
			then target
			else [ target ]
		else targets;

	outputs' = lib.forEach targets' (target: {
		"linux-${target}" = withPatchelf patchelfer.${target} linuxPkgs.${target};

		# This isn't very useful.
		# "nixos-${target}" = wrapGApps linuxPkgs.${target};
	});

	outputs = lib.foldl (a: b: a // b) {} outputs';

in output "${base.pname}-cross" outputs
