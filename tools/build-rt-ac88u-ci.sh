#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

toolchain_root="${AM_TOOLCHAINS_ROOT:-$(cd "$repo_root/.." && pwd)/am-toolchains}"

sdk_root="$toolchain_root/brcm-arm-sdk"

compiler_dir="$sdk_root/hndtools-arm-linux-2.6.36-uclibc-4.5.3/bin"
toolchain_lib="$sdk_root/hndtools-arm-linux-2.6.36-uclibc-4.5.3/lib"

build_dir="$repo_root/release/src-rt-7.14.114.x/src"

compiler="$compiler_dir/arm-brcm-linux-uclibcgnueabi-gcc"

if [[ ! -x "$compiler" ]]; then
  echo "Missing Broadcom ARM SDK compiler: $compiler" >&2
  exit 1
fi

if [[ ! -d "$toolchain_lib" ]]; then
  echo "Missing toolchain lib directory: $toolchain_lib" >&2
  exit 1
fi

if [[ ! -d "$repo_root/.git" ]]; then
  echo "Missing .git metadata under $repo_root (needed for versioning)." >&2
  exit 1
fi

# Prefer system host tools (autoreconf/autoconf/...) over broken SDK copies.
export PATH="/usr/bin:/bin:$compiler_dir:$PATH"
# Single-entry only. samba-3.5.8 configure does
#   PTHREAD_LDFLAGS="$LD_LIBRARY_PATH/../arm-brcm-.../libpthread.a"
# Multi-path LD_LIBRARY_PATH breaks that string concat. Host i386 libs
# for the cross cc1 are installed via ldconfig in the workflow.
export LD_LIBRARY_PATH="$toolchain_lib"
export AUTOCONF="${AUTOCONF:-/usr/bin/autoconf}"
export AUTOM4TE="${AUTOM4TE:-/usr/bin/autom4te}"
export AUTOHEADER="${AUTOHEADER:-/usr/bin/autoheader}"
export AUTOMAKE="${AUTOMAKE:-/usr/bin/automake}"
export ACLOCAL="${ACLOCAL:-/usr/bin/aclocal}"
export AUTORECONF="${AUTORECONF:-/usr/bin/autoreconf}"

echo "Repository: $repo_root"
echo "Build tree: $build_dir"
echo "Toolchain: $compiler_dir"
echo "Toolchain libs: $toolchain_lib"
echo "Git HEAD: $(git -C "$repo_root" rev-parse --short HEAD)"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo "Host: $(uname -a)"
echo "Compiler: $(arm-brcm-linux-uclibcgnueabi-gcc --version | head -n 1)"
echo "autoreconf: $(command -v autoreconf) ($(autoreconf --version | head -n1))"

arm-brcm-linux-uclibcgnueabi-gcc --version
ldd "$sdk_root/hndtools-arm-linux-2.6.36-uclibc-4.5.3/libexec/gcc/arm-brcm-linux-uclibcgnueabi/4.5.3/cc1"

# Old GPL packages (e.g. sdparm-1.02) re-run host automake and expect
# aux scripts modern automake ships. Tree often only has install-sh/depcomp.
automake_libdir="$(automake --print-libdir 2>/dev/null || true)"
if [[ -n "$automake_libdir" && -d "$automake_libdir" ]]; then
  echo "Seeding automake aux files from $automake_libdir"
  while IFS= read -r conf; do
    d="$(dirname "$conf")"
    for aux in compile missing install-sh depcomp config.guess config.sub ar-lib test-driver; do
      if [[ ! -e "$d/$aux" && -f "$automake_libdir/$aux" ]]; then
        cp -a "$automake_libdir/$aux" "$d/$aux"
        echo "  + $d/$aux"
      fi
    done
    # Keep shipped Makefile.in/configure newer than inputs so make does not
    # force a full autotools regen with mismatched host automake.
    for gen in Makefile.in configure aclocal.m4 config.h.in; do
      if [[ -f "$d/$gen" ]]; then
        touch "$d/$gen"
      fi
    done
  done < <(find "$repo_root/release/src/router" -maxdepth 3 \( -name configure.ac -o -name configure.in \) -type f | sort)
fi

# Old GPL packages re-run host automake when timestamps drift. Stub AUTO* tools
# so make rules that call $(AUTOMAKE)/$(AUTOCONF) become no-ops; configure
# scripts already shipped in-tree are used as-is.
stub_bin="$(mktemp -d)"
for t in automake aclocal autoconf autoheader autoreconf autom4te; do
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$stub_bin/$t"
  chmod +x "$stub_bin/$t"
done
export PATH="$stub_bin:/usr/bin:/bin:$compiler_dir"
export AUTOMAKE="$stub_bin/automake"
export ACLOCAL="$stub_bin/aclocal"
export AUTOCONF="$stub_bin/autoconf"
export AUTOHEADER="$stub_bin/autoheader"
export AUTORECONF="$stub_bin/autoreconf"
export AUTOM4TE="$stub_bin/autom4te"
# Prefer shipped configure/Makefile.in over sources for all router packages.
find "$repo_root/release/src/router" -type f \( -name Makefile.in -o -name configure -o -name aclocal.m4 -o -name config.h.in \) -print0 \
  | xargs -0 -r touch -c
make -C "$build_dir" \
  LD_LIBRARY_PATH="$toolchain_lib" \
  PATH="$PATH" \
  AUTOCONF="$AUTOCONF" \
  AUTOM4TE="$AUTOM4TE" \
  AUTOHEADER="$AUTOHEADER" \
  AUTOMAKE="$AUTOMAKE" \
  ACLOCAL="$ACLOCAL" \
  AUTORECONF="$AUTORECONF" \
  rt-ac88u

image_dir="$build_dir/image"

echo "Generated firmware images:"

find "$image_dir" \
  -maxdepth 1 \
  -type f \
  -name "*.trx" \
  -print \
  -exec sha256sum {} \;

if ! find "$image_dir" -maxdepth 1 -type f -name "*.trx" | grep -q .; then
  echo "Build completed without generating a TRX image." >&2
  exit 1
fi
