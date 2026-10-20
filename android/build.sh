#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
. android/cross-env.sh
command -v cargo >/dev/null
command -v bun >/dev/null
# This override avoids the nightly's empty metadata-only object files in cross builds.
# Keep the upstream workspace's development profile/config unchanged.
if [ "${1:-}" = --check ]; then
    exec cargo --config unstable.embed-metadata=true --config profile.dev.build-override.codegen-units=1 check --locked -p pi-natives --target aarch64-linux-android
fi
: "${OMP_ANDROID_BUN:?Set OMP_ANDROID_BUN to the official Android ARM64 Bun executable}"
cargo --config unstable.embed-metadata=true --config profile.ci.build-override.codegen-units=1 build --locked -p pi-natives --target aarch64-linux-android --profile ci
mkdir -p android/dist
cp "${CARGO_TARGET_DIR:-target}"/aarch64-linux-android/ci/libpi_natives.so packages/natives/native/pi_natives.android-arm64.node
bun scripts/stamp-native-version.ts packages/natives/native/pi_natives.android-arm64.node
bun --cwd=packages/stats run gen:stats
trap 'bun --cwd=packages/stats run gen:stats:reset' EXIT
bun android/bundle.ts
cp LICENSE THIRD-PARTY-NOTICES.txt ANDROID.md android/dist/
(
    cd android/dist
    tar -czf omp-android-arm64.tar.gz omp LICENSE THIRD-PARTY-NOTICES.txt ANDROID.md
    sha256sum omp-android-arm64.tar.gz > SHA256SUMS
)
