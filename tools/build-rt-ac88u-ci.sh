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

export PATH="$compiler_dir:$PATH"
export LD_LIBRARY_PATH="$toolchain_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

echo "Repository: $repo_root"
echo "Build tree: $build_dir"
echo "Toolchain: $compiler_dir"
echo "Toolchain libs: $toolchain_lib"
echo "Host: $(uname -a)"
echo "Compiler: $(arm-brcm-linux-uclibcgnueabi-gcc --version | head -n 1)"

arm-brcm-linux-uclibcgnueabi-gcc --version
ldd "$(dirname "$(dirname "$compiler_dir")")/libexec/gcc/arm-brcm-linux-uclibcgnueabi/4.5.3/cc1" || true

make -C "$build_dir" rt-ac88u

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