#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

toolchain_root="${AM_TOOLCHAINS_ROOT:-$(cd "$repo_root/.." && pwd)/am-toolchains}"

sdk_root="$toolchain_root/brcm-arm-sdk"

compiler_dir="$sdk_root/hndtools-arm-linux-2.6.36-uclibc-4.5.3/bin"
toolchain_lib="$sdk_root/hndtools-arm-linux-2.6.36-uclibc-4.5.3/lib"
firmware_target="${FIRMWARE_TARGET:-rt-ac88u}"

case "$firmware_target" in
  rt-ac88u|rt-ac3100|rt-ac5300) ;;
  *)
    echo "Unsupported SDK7 firmware target: $firmware_target" >&2
    exit 2
    ;;
esac

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
echo "Build target: $firmware_target"
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


# Packages with shipped Automake 1.9/1.10 aclocal that host 1.16 rejects if
# make decides to regenerate. Freeze generated files + seed aux scripts.
# Packages that already run "autoreconf -i -f" (libxml2, curl, wget, …) are OK.
# Do NOT stub AUTO* globally — those need real host autotools.
freeze_pkgs=(
  sdparm-1.02
  accel-pptp
  accel-pptp/src
  accel-pptpd/pptpd-1.3.3
  accel-pptpd/pppd_plugin
  accel-pptpd/pppd_plugin/src
  pptpd
  bridge
  haveged
  hotplug-e2-helper
  json-c
  pcre-8.31
  phddns
  libusb
  libusb10
  libupnp-1.3.1
  libdaemon
  libogg
  libvorbis
  libpng
  libyaml
  libffi-3.0.11
  libgcrypt-1.5.1
  libgpg-error-1.10
  libiconv-1.14
  lzo
  lzo-2.10
  lighttpd-1.4.39
  ntfs-3g
  openpam
  netatalk-3.0.5
  nfs-utils-1.3.4
)
automake_libdir="$(automake --print-libdir 2>/dev/null || true)"
for pkg in "${freeze_pkgs[@]}"; do
  d="$repo_root/release/src/router/$pkg"
  [[ -d "$d" ]] || continue
  if [[ -n "$automake_libdir" ]]; then
    for aux in compile missing install-sh depcomp config.guess config.sub ar-lib test-driver; do
      if [[ ! -e "$d/$aux" && -f "$automake_libdir/$aux" ]]; then
        cp -a "$automake_libdir/$aux" "$d/$aux"
      fi
    done
  fi
  # Prefer shipped generated files over sources for make dependency checks.
  find "$d" -maxdepth 2 -type f \( \
      -name aclocal.m4 -o -name configure -o -name config.h.in \
      -o -name Makefile.in -o -name 'stamp-h*' \
    \) -exec touch {} +
done
make -C "$build_dir" \
  LD_LIBRARY_PATH="$toolchain_lib" \
  PATH="$PATH" \
  AUTOCONF="$AUTOCONF" \
  AUTOM4TE="$AUTOM4TE" \
  AUTOHEADER="$AUTOHEADER" \
  AUTOMAKE="$AUTOMAKE" \
  ACLOCAL="$ACLOCAL" \
  AUTORECONF="$AUTORECONF" \
  "$firmware_target"

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
