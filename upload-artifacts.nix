{ pkgs }:

let
	mksh = name: text: pkgList: pkgs.writeShellScript name ''
		for deriv in ${pkgs.lib.concatStringsSep " " pkgList}; {
			export PATH="$deriv/bin:$PATH"
		}

		exec ${text}
	'';
in
	
# TODO: port this to pkgs.writeShellApplication
mksh "upload-artifacts"
	"${./upload-artifacts.sh} \"$@\""
	(with pkgs; [
		jq
		curl
		coreutils
		findutils
	])
