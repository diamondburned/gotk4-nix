{ ... }:

let pkgs = import ./pkgs.nix {};
	mksh = name: text: pkgList: pkgs.writeShellScript name ''
		for deriv in ${pkgs.lib.concatStringsSep " " pkgList}; {
			export PATH="$deriv/bin:$PATH"
		}

		${text}
	'';

in mksh "upload-artifacts"
	"${./upload-artifacts.sh} \"$@\""
	(with pkgs; [
		jq
		curl
		coreutils
		findutils
	])
