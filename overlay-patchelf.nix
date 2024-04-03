final: prev: {
	patchelfer = system: interpreter: prev.writeShellScriptBin
		"patchelf-${system}"
		"${prev.patchelf}/bin/patchelf --set-interpreter ${interpreter} \"$@\"";
	# See https://sourceware.org/glibc/wiki/ABIList.
	patchelf-x86_64-linux  = final.patchelfer "x86_64-linux"  "/lib64/ld-linux-x86-64.so.2";
	patchelf-aarch64-linux = final.patchelfer "aarch64-linux" "/lib/ld-linux-aarch64.so.1";
}
