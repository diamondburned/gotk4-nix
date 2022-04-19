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
nix-build .nix --argstr action build-cross
nix-build .nix --argstr action build-package
```

```nix
{}: import ./.nix { action = "shell"; }
```

### build-cross

`build-package` cross-compiles for Linux x86_64 and aarch64. It generates the
following:

```
result
├── gtkcord4-linux-aarch64.tar.gz
├── gtkcord4-linux-x86_64.tar.gz
├── gtkcord4-nixos-aarch64.tar.gz
└── gtkcord4-nixos-x86_64.tar.gz
```

### build-package

`build-package` creates a proper Nix package. It generates the following:

```
```
