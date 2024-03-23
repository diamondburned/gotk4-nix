self: super: {
	patchelfer = arch: interpreter: super.writeShellScriptBin
		"patchelf-${arch}"
		''
			${super.patchelf}/bin/patchelf \
				--set-interpreter ${interpreter} \
				--remove-rpath \ # clear RPATH, see https://github.com/diamondburned/dissent/issues/255
				"$@"
		'';
	# See https://sourceware.org/glibc/wiki/ABIList.
	patchelf-x86_64  = self.patchelfer "x86_64"  "/lib64/ld-linux-x86-64.so.2";
	patchelf-aarch64 = self.patchelfer "aarch64" "/lib/ld-linux-aarch64.so.1";
}
