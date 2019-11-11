#!/bin/bash

#
# make_implib
# Given libxyz-1.dll, create import library libxyz-1.lib
# see https://stackoverflow.com/a/53838952/5222966
#
# - machine: i386, i386:x86-64, arm, arm64
# - working_dir
# - dll: *.dll
# - dlla: *.dll.a
#
make_implib() {
    local machine=$1
    local working_dir=$2
    local dll=$3
    local dlla=$4
    local dllname dllaname name deffile libfile

    dllname="${dll##*/}"                      # libYYY.dll
    dllfile="${working_dir}/bin/${dllname}"   # /dir/bin/libYYY.dll
    dllaname="${dlla##*/}"                    # libXXX.dll.a
    name_ext="${dllaname#lib}"                # XXX.dll.a
    name="${name_ext%.dll.a}"                 # XXX
    deffile="${working_dir}/lib/${name}.def"  # /dir/lib/XXX.def
    libfile="${working_dir}/lib/${name}.lib"  # /dir/lib/XXX.def
    echo $dllfile
    echo $dllname
    echo $deffile
    echo $libfile

    # Extract exports from the .edata section, writing results to the .def file.
    LC_ALL=C objdump -p "$dllfile" | awk -vdllname="$dllname" '
    /^\[Ordinal\/Name Pointer\] Table$/ {
        print "LIBRARY " dllname
        print "EXPORTS"
        p = 1; next
    }
    p && /^\t\[ *[0-9]+\] [a-zA-Z0-9_]+$/ {
        gsub("\\[|\\]", "");
        print "    " $2 " @" $1;
        ++p; next
    }
    p > 1 && /^$/ { exit }
    p { print "; unexpected objdump output:", $0; exit 1 }
    END { if (p < 2) { print "; cannot find export data section"; exit 1 } }
    ' > "$deffile"

    # Create .lib suitable for MSVC. Cannot use binutils dlltool as that creates
    # an import library (like the one found in lib/*.dll.a) that results in
    # broken executables. For example, assume executable foo.exe that uses fnA
    # (from liba.dll) and fnB (from libb.dll). Using link.exe (14.00.24215.1)
    # with these broken .lib files results in an import table that lists both
    # fnA and fnB under both liba.dll and libb.dll. Use of llvm-dlltool creates
    # the correct archive that uses Import Headers (like official MS tools).
    #llvm-dlltool -m "$machine" -d "$deffile" -l "$libfile"
    llvm-dlltool -d "$deffile" -l "$libfile"
    rm -f "$deffile"
}


#
# Main
#
# - arch: i386, i386:x86-64, arm, arm64
# - working_dir
#
#
main() {
    local arch=$1
    local working_dir=$2
    local implibs dll_a_name dllnames

    implibs=`ls ${working_dir}/lib/*.dll.a`
    for implib in $implibs
    do
        echo "*** ${implib}"

        # get dll names from the dll.a
        dll_a_name="${implib##*/}"
        dllnames=`dlltool -I ${implib}`

        # make the lib file
        for dll in $dllnames
        do
            # make implib
            make_implib $arch $working_dir $dll $dll_a_name
        done
    done
}


# bin/*.dll
# lib/*.a
# lib/*.dll.a
# lib/*.lib
# lib/*.exp
# lib/*.def
# lib/pkgconfig/*.pc

# vorbisfile:
# bin/libvorbisfile-3.dll   dll / output of dlltool
# lib/vorbisfile.pc         pc
# lib/libvorbisfile.dll.a   implib / dlla
# lib/vorbisfile.def        def
# lib/vorbisfile.exp        exp
# lib/vorbisfile.lib        lib

arch=$1
working_dir=$2
main ${arch} ${working_dir}
