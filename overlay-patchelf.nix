final: prev: {
	patchelfer = arch: interpreter: prev.writeShellScriptBin
		"patchelf-${arch}"
		"${prev.patchelf}/bin/patchelf --set-interpreter ${interpreter} \"$@\"";
	# See https://sourceware.org/glibc/wiki/ABIList.
	patchelf-x86_64  = final.patchelfer "x86_64"  "/lib64/ld-linux-x86-64.so.2";
	patchelf-aarch64 = final.patchelfer "aarch64" "/lib/ld-linux-aarch64.so.1";
}
