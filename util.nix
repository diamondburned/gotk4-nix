pkgs: rec {
	optionalVersion = base: version:
		if (version != null) then version else
		if (base ? version && base.version != null) then base.version else
		"unknown";
}
