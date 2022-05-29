{
	pkgs,
	loaders ? (with pkgs; [
			(lib.getLib gdk-pixbuf)
			(lib.getLib librsvg)
	]),
}:

let lib = pkgs.lib;
	loaderPaths = lib.concatMapStrings (p: "${p}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache") loaders;

in pkgs.stdenv.mkDerivation {
	name = "webp-pixbuf-loader";
	version = "0.0.4";

	src = pkgs.fetchzip {
		url = "https://github.com/aruiz/webp-pixbuf-loader/archive/refs/tags/0.0.4.tar.gz";
		sha256 = "1kshsz91mirjmnmv796nba1r8jg8a613anhgd38dhh2zmnladcwn";
	};

	buildInputs = with pkgs; [
		glib
		gtk3
		gdk-pixbuf
		libwebp
	];

	nativeBuildInputs = with pkgs; [
		meson
		ninja
		pkg-config
	];

	# Thanks, tdeo!
	postPatch = ''
		substituteInPlace meson.build \
			--replace \
					"gdk_pb_query_loaders = find_program(get_option('gdk_pixbuf_query_loaders_path'), gdk_pb_query_loaders, gdk_pb_query_loaders+'-32', gdk_pb_query_loaders+'-64')" \
					"gdk_pb_query_loaders = find_program('gdk-pixbuf-query-loaders', dirs: '${pkgs.gdk-pixbuf.dev}/bin')" \
			--replace \
					"gdk_pb_moddir = gdkpb.get_pkgconfig_variable('gdk_pixbuf_moduledir')" \
					"gdk_pb_moddir = join_paths(get_option('libdir'), 'gdk-pixbuf-2.0/@0@/loaders'.format(gdkpb.get_pkgconfig_variable('gdk_pixbuf_binary_version')))"
	'';

├── lib
│   └── gdk-pixbuf-2.0
│       └── 2.10.0
│           └── loaders
│               └── libpixbufloader-webp.so
└── share
    └── thumbnailers
        └── webp-pixbuf.thumbnailer

	# See https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/libraries/librsvg/default.nix.
	postConfigure = ''
		GDK_PIXBUF_VERSION=2.10.0
		GDK_PIXBUF=$out/lib/gdk-pixbuf-2.0/$GDK_PIXBUF_VERSION

		sed -e "s#gdk_pixbuf_moduledir = .*#gdk_pixbuf_moduledir = $GDK_PIXBUF/loaders#" \
			-i gdk-pixbuf-loader/Makefile
		sed -e "s#gdk_pixbuf_cache_file = .*#gdk_pixbuf_cache_file = $GDK_PIXBUF/loaders.cache#" \
			-i gdk-pixbuf-loader/Makefile
		sed -e "s#\$(GDK_PIXBUF_QUERYLOADERS)#GDK_PIXBUF_MODULEDIR=$GDK_PIXBUF/loaders \$(GDK_PIXBUF_QUERYLOADERS)#" \
			-i gdk-pixbuf-loader/Makefile

		# Fix thumbnailer path
		# sed -e "s#@bindir@\(/gdk-pixbuf-thumbnailer\)#${pkgs.gdk-pixbuf}/bin\1#g" \
		# 		-i gdk-pixbuf-loader/webp-pixbuf.thumbnailer.in
	'';
	postInstall = lib.optionalString (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) ''
		cat $GDK_PIXBUF/loaders.cache ${loaderPaths} > $GDK_PIXBUF/loaders.cache.tmp
		mv $GDK_PIXBUF/loaders.cache.tmp $GDK_PIXBUF/loaders.cache
	'';
}
