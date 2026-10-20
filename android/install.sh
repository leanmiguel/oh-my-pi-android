#!/bin/sh
# Install a verified native Android release. No Bun or compiler is needed.
set -eu
repo=leanmiguel/oh-my-pi-android
asset=omp-android-arm64.tar.gz
[ "$(uname -m)" = aarch64 ] || { echo "This installer requires Android ARM64 (aarch64)." >&2; exit 1; }
[ -n "${PREFIX:-}" ] && [ -x "$PREFIX/bin/termux-info" ] || { echo "Run this installer inside native Termux." >&2; exit 1; }
for command in curl jq sha256sum tar mktemp; do
    command -v "$command" >/dev/null || { echo "Missing $command. Run: pkg install curl jq coreutils tar" >&2; exit 1; }
done
if command -v getprop >/dev/null; then
    api=$(getprop ro.build.version.sdk)
    case $api in ''|*[!0-9]*) echo "Cannot determine Android API level." >&2; exit 1 ;; esac
    [ "$api" -ge 28 ] || { echo "Android 9 (API 28) or newer is required." >&2; exit 1; }
fi
release=${OMP_ANDROID_RELEASE:-}
if [ -z "$release" ]; then
    release=$(curl -fsSL --retry 3 "https://api.github.com/repos/$repo/releases/latest" | jq -er .tag_name) || {
        echo "No Android release is available. Check the repository's Android build workflow." >&2; exit 1;
    }
fi
case $release in ''|*[!A-Za-z0-9._-]*) echo "Invalid release tag." >&2; exit 1 ;; esac
install_dir=${OMP_ANDROID_INSTALL_DIR:-$HOME/.local/bin}
mkdir -p "$install_dir"
staging=$(mktemp -d "$install_dir/.omp-android.XXXXXX")
cleanup() { [ ! -d "$staging" ] || rm -r -- "$staging"; }
trap cleanup EXIT HUP INT TERM
base="https://github.com/$repo/releases/download/$release"
curl -fL --retry 3 "$base/$asset" -o "$staging/$asset"
curl -fsSL --retry 3 "$base/SHA256SUMS" -o "$staging/SHA256SUMS"
(
    cd "$staging"
    awk '$2 == "omp-android-arm64.tar.gz" { print }' SHA256SUMS > selected.sha256
    [ "$(wc -l < selected.sha256)" -eq 1 ] || { echo "Missing or duplicate release checksum." >&2; exit 1; }
    sha256sum -c selected.sha256
    # Reject unexpected members before extracting a downloaded archive.
    tar -tzf "$asset" | while IFS= read -r member; do
        case $member in omp|LICENSE|THIRD-PARTY-NOTICES.txt|ANDROID.md) ;; *) echo "Unexpected archive member: $member" >&2; exit 1 ;; esac
    done
    tar -xzf "$asset" -- omp
    [ -f omp ] && [ ! -L omp ] || { echo "The release must contain a regular executable." >&2; exit 1; }
    chmod 755 omp
    ./omp --version
    ./omp --help >/dev/null
)
# The replacement is on the same filesystem and occurs only after verification.
mv -- "$staging/omp" "$install_dir/omp"
echo "Installed $release to $install_dir/omp"
case :$PATH: in *:"$install_dir":*) ;; *) printf 'Add to your shell configuration: export PATH="%s:$PATH"\n' "$install_dir" ;; esac
