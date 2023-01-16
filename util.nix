pkgs: rec {
	shortrev = rev: builtins.substring 0 7 rev;

	optionalVersion = base: rev:
		if (base ? version && base.version != null) then base.version else
		if (rev != null) then shortrev rev else
		"unknown";
}
