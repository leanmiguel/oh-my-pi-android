#!/bin/sh
# Source this file before invoking Cargo for Android from a Linux build host.
# ANDROID_NDK_HOME must point to an Android NDK r27 installation or newer.
: "${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME to an Android NDK r27+ directory}"
OMP_ANDROID_API=${OMP_ANDROID_API:-28}
OMP_ANDROID_TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64
if [ ! -x "$OMP_ANDROID_TOOLCHAIN/bin/aarch64-linux-android${OMP_ANDROID_API}-clang" ]; then
    echo "Android compiler not found in $OMP_ANDROID_TOOLCHAIN" >&2
    return 1
fi
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$OMP_ANDROID_TOOLCHAIN/bin/aarch64-linux-android${OMP_ANDROID_API}-clang"
export CC_aarch64_linux_android="$CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER"
export CXX_aarch64_linux_android="$OMP_ANDROID_TOOLCHAIN/bin/aarch64-linux-android${OMP_ANDROID_API}-clang++"
export AR_aarch64_linux_android="$OMP_ANDROID_TOOLCHAIN/bin/llvm-ar"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"
export PCRE2_SYS_STATIC=1
