let systemPkgs = import <nixpkgs> {};

in {
	nixpkgs = systemPkgs.fetchFromGitHub {
		owner = "NixOS";
		repo  = "nixpkgs";
		rev   = "0f316e4d72da";
		hash  = "sha256:0vh0fk5is5s9l0lxpi16aabv2kk1fwklr7szy731kfcz9gdrr65l";
	};
}
