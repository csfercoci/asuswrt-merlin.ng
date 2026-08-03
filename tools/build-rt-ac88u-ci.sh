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
export LD_LIBRARY_PATH="$toolchain_lib:/usr/lib/i386-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
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

make -C "$build_dir" \
  LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \
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