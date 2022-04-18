# gotk4-nix

## Usage

Create `.nix/default.nix`

```nix
{ action }:

let src = import ./src.nix;

in import "${src.gotk4-nix}/${action}.nix" {
	base = import ./base.nix;
}
```

Use like so:

```sh
nix-build .nix --argstr action cross-build
nix-build .nix --argstr action package-build
```

```nix
{}: import ./.nix { action = "shell"; }
```

### cross-build

`cross-build` cross-compiles for x86_64 and aarch64. It generates the following:

```
result
├── gtkcord4-linux-aarch64.tar.gz
├── gtkcord4-linux-x86_64.tar.gz
├── gtkcord4-nixos-aarch64.tar.gz
└── gtkcord4-nixos-x86_64.tar.gz
```

### package-build

`package-buld` creates a proper Nix package. It generates the following:

```
```
