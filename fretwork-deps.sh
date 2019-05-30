#!/bin/bash

#
# Constants
#
PREFIX=`pwd`/deps
HOST=$PLATFORM
COMMON_AUTOCONF_FLAGS="--prefix=${PREFIX} --host=${HOST} --disable-static --enable-shared CPPFLAGS=-I${PREFIX}/include LDFLAGS=-L${PREFIX}/lib"
CROSS_GCC=${PLATFORM}-gcc

#
# Path
#
export PATH="${PREFIX}/bin:${PATH}"


#
# Info
#
info()
{
    message=$1
    echo "[INFO] ${message}"
}


#
# Download
#
download()
{
    url=$1
    filename=`basename $1`
    wget -q $filename $url

    # copy urls
    echo $1 >> ${PREFIX}/URLs
}


#
# Build the workspace
#
build_workspace()
{
    info "Build the workspace"

    mkdir -p $PREFIX
    mkdir -p "${PREFIX}/bin" "${PREFIX}/lib" "${PREFIX}/include"
    mkdir -p "${PREFIX}/lib/pkgconfig"

    # pkg-config wrapper
    cat >"${PREFIX}"/bin/pkg-config <<EOF
#!/bin/sh -e
exec env PKG_CONFIG_LIBDIR='$PREFIX'/lib/pkgconfig '`which pkg-config`' "\$@"
EOF
    chmod -v 0755 "$PREFIX"/bin/pkg-config

    # compiler wrapper
    cat >"$PREFIX"/bin/"$CROSS_GCC" <<"EOF"
#!/usr/bin/python
import sys, os
STATIC_LIBS = ['-lstdc++', '-lgcc', '-lgcc_eh']
def fixed_args(args):
    for n, arg in enumerate(args):
        if arg in STATIC_LIBS:
            yield '-Wl,-Bstatic'
        yield arg
        if arg in STATIC_LIBS:
            yield '-Wl,--exclude-libs,lib%s.a,-Bdynamic' % arg[2:]
        if n == 0:
            yield '-static-libgcc'
            yield '-static-libstdc++'
            yield '-mpreferred-stack-boundary=2'
            yield '-mincoming-stack-boundary=2'
for p in os.environ['PATH'].split(os.pathsep):
    candidate = os.path.join(p, os.path.basename(__file__))
    if os.access(candidate, os.X_OK) and not os.path.samefile(candidate, __file__):
        os.execv(candidate, list(fixed_args(sys.argv)))
EOF
    chmod -v 0755 "$PREFIX"/bin/"$CROSS_GCC"
    ln -svf "$CROSS_GCC" "$PREFIX"/bin/"$CROSS_GXX"
}


#
# Build iconv
#
build_iconv()
{
    iconv_version="0.0.8"
    info "Build iconv ${iconv_version}"

    # download
    download https://github.com/win-iconv/win-iconv/archive/v${iconv_version}.tar.gz
    tar zxf v${iconv_version}.tar.gz

    # compile
    cd win-iconv-${iconv_version}
    make CC=$CROSS_GCC iconv.dll

    # copy files
    cp iconv.dll ${PREFIX}/bin
    cp iconv.h ${PREFIX}/include
    cp libiconv.dll.a "${PREFIX}"/lib
    cd ..
}


#
# Build zlib
#
build_zlib()
{
    zlib_version="1.2.11"
    info "Build zlib ${zlib_version}"

    # download
    download http://www.zlib.net/zlib-${zlib_version}.tar.gz
    tar zxf zlib-${zlib_version}.tar.gz

    # compile
    cd zlib-${zlib_version}
    make -f win32/Makefile.gcc PREFIX="${PLATFORM}"- zlib1.dll
    cp zlib.h zconf.h "${PREFIX}"/include
    cp zlib1.dll "${PREFIX}"/bin
    cp libz.dll.a "${PREFIX}"/lib
    cd ..
}


#
# Build gettext
#
build_gettext()
{
    gettext_version="0.18.3"
    info "Build gettext ${gettext_version}"

    # download
    download http://ftp.gnu.org/gnu/gettext/gettext-${gettext_version}.tar.gz
    tar zxf gettext-${gettext_version}.tar.gz

    # compile
    cd gettext-${gettext_version}/gettext-runtime
    ./configure $COMMON_AUTOCONF_FLAGS -disable-java --disable-csharp --enable-relocatable --disable-libasprintf
    make
    make install
    cd ../..
}


#
# Build libffi
#
build_libffi()
{
    libffi_version="3.0.12"
    info "Build libffi ${libffi_version}"

    # download
    download ftp://sourceware.org/pub/libffi/libffi-${libffi_version}.tar.gz
    tar zxf libffi-${libffi_version}.tar.gz

    # compile
    cd libffi-${libffi_version}
    ./configure $COMMON_AUTOCONF_FLAGS --enable-portable-binary
    make
    make install
    cd ..
}


#
# Build GLib
#
build_glib()
{
    #
    # deps
    #
    build_gettext
    build_libffi

    #
    # glib
    #
    # https://developer.gnome.org/glib/2.34/
    glib_version="2.34.3"
    info "Build GLib ${glib_version}"

    # download
    glib_name="glib-${glib_version}"
    glib_url="http://ftp.gnome.org/pub/GNOME/sources/glib/${glib_version%.*}/${glib_name}.tar.xz"
    download ${glib_url}
    tar Jxf ${glib_name}.tar.xz

    # compile
    cd ${glib_name}
    ./configure $COMMON_AUTOCONF_FLAGS --disable-modular-tests
    make -C glib
    make -C gthread
    make -C glib install
    make -C gthread install

    # copy files
    cp -v glib-2.0.pc gthread-2.0.pc ${PREFIX}/lib/pkgconfig
    cd ..
}


#
# Build pkg-config
#
build_pkgconfig()
{
    pkgconfig_version="0.28"
    info "Build pkg-config ${pkgconfig_version}"

    # download
    download http://pkgconfig.freedesktop.org/releases/pkg-config-${pkgconfig_version}.tar.gz
    tar zxf pkg-config-${pkgconfig_version}.tar.gz

    # compile
    cd pkg-config-${pkgconfig_version}
    ./configure $COMMON_AUTOCONF_FLAGS
    make
    make install
    cd ..
}


#
# Build libogg
#
build_libogg()
{
    libogg_version="1.3.0"
    info "Build libogg ${libogg_version}"

    # download
    download http://downloads.xiph.org/releases/ogg/libogg-${libogg_version}.tar.xz
    tar Jxf libogg-${libogg_version}.tar.xz

    # compile
    cd libogg-${libogg_version}
    ./configure $COMMON_AUTOCONF_FLAGS
    make
    make install
    cd ..
}


#
# Build libtheora
#
build_libtheora()
{
    libtheora_version="1.2.0alpha1"
    info "Build libtheora ${libtheora_version}"

    # download
    download http://downloads.xiph.org/releases/theora/libtheora-${libtheora_version}.tar.xz
    tar Jxf libtheora-${libtheora_version}.tar.xz

    # compile
    cd libtheora-${libtheora_version}
    # fix .def files of theora use CRLF line terminators, which makes the new
    # binutils trigger a linker error:
    # /usr/bin/i686-w64-mingw32-ld: .libs/libtheoradec-1.dll.def:3: syntax error
    sed -i -e 's#\r##g' win32/xmingw32/libtheoradec-all.def
    sed -i -e 's#\r##g' win32/xmingw32/libtheoraenc-all.def
    # config, make, install
    ./configure $COMMON_AUTOCONF_FLAGS --disable-examples --without-vorbis --disable-oggtest --with-ogg-includes=${PREFIX}/include --with-ogg-libraries=${PREFIX}/lib
    make
    make install
    cd ..
}


#
# Build libvorbis
#
build_libvorbis()
{
    libvorbis_version="1.3.3"
    info "Build libvorbis ${libvorbis_version}"

    # download
    download http://downloads.xiph.org/releases/vorbis/libvorbis-${libvorbis_version}.tar.xz
    tar Jxf libvorbis-${libvorbis_version}.tar.xz

    # compile
    cd libvorbis-${libvorbis_version}
    ./configure $COMMON_AUTOCONF_FLAGS
    make
    make install
    cd ..
}


#
# Build soundtouch
#
build_soundtouch()
{
    soundtouch_version="1.7.1"
    info "Build soundtouch ${soundtouch_version}"

    # download
    download http://www.surina.net/soundtouch/soundtouch-${soundtouch_version}.tar.gz
    tar zxf soundtouch-${soundtouch_version}.tar.gz

    # compile
    cd soundtouch
    ./bootstrap
    ./configure $COMMON_AUTOCONF_FLAGS
    make LDFLAGS=-no-undefined
    make install
    cd ..
}


#
# Build SDL
#
build_sdl()
{
    sdl_version="1.2.15"
    info "Build SDL ${sdl_version}"

    # download
    download http://www.libsdl.org/release/SDL-${sdl_version}.tar.gz
    tar zxf SDL-${sdl_version}.tar.gz

    # compile
    cd SDL-${sdl_version}
    ./configure $COMMON_AUTOCONF_FLAGS
    make
    make install

    # copy files
    mv "${PREFIX}"/lib/libSDLmain.a "${PREFIX}"/lib/SDLmain.lib
    rm -f "${PREFIX}"/lib/libSDLmain.la
    cp include/SDL_config_win32.h "${PREFIX}"/include/SDL/SDL_config.h
    cd ..
}


#
# Build SDL Mixer
#
build_sdl_mixer()
{
    # deps
    build_sdl

    sdl_mixer_version="1.2.12"
    info "Build SDL Mixer ${sdl_mixer_version}"

    # download
    download http://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-${sdl_mixer_version}.tar.gz
    tar zxf SDL_mixer-${sdl_mixer_version}.tar.gz

    # compile
    cd SDL_mixer-${sdl_mixer_version}
    ./configure $COMMON_AUTOCONF_FLAGS --disable-music-mod --disable-music-midi --disable-music-mp3
    make
    make install
    cd ..
}


#
# Package all deps
#
package_dist()
{
    info "Package deps"

    # copy deps into dist
    mkdir -p dist
    cp -a deps dist
    ls -l dist/deps

    # remove unecessary files (except bin and lib)
    info "Remove doc and share"
    rm -rf dist/deps/{doc,share}

    # remove libtool libs, .def files and unecessary scripts
    info "Remove libtool and def files"
    ls -l dist/deps/lib/{*.la,*.def}
    rm -rf dist/deps/lib/{*.la,*.def}
    rm -rf dist/deps/bin/pkg-config

    # generate .def files
    python2 makedefs.py dist/deps/lib dist/deps/bin "${PLATFORM}-dlltool -I"

    # strip binaries and libs
    ${PLATFORM}-strip --strip-all dist/deps/bin/*.exe dist/deps/bin/*.dll
    ${PLATFORM}-strip --strip-debug dist/deps/lib/*.lib dist/deps/lib/*.a

    # make a README
    cat readme.template dist/deps/URLs > dist/README.md
    rm -rf dist/deps/URLs

    # debug ls
    echo "debug 0"
    find . -name "*vorbisfile*"

    # create the tarball
    cd dist
    tarball="fretwork-${WIN}-deppack-`date +%Y%m%d`.tar.gz"
    tar zcf ../${tarball} *
    cd ..

    # Copy the tarball to out
    mkdir -p out
    cp ${tarball} out/
}


#
# Main
#
main()
{
    build_workspace
    build_iconv
    build_zlib
    build_glib
    build_pkgconfig
    build_libogg
    build_libtheora
    build_libvorbis
    build soundtouch
    build_sdl_mixer

    package_dist
}
#main
