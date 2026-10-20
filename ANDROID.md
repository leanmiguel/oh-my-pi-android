# OMP for Android

This fork adds native Termux support to OMP on **ARM64 Android 9 or newer**.
It uses Android's Bionic libc. Linux ARM64/glibc binaries are not interchangeable
with Android binaries. Root and PRoot are not required.

The Android implementation lives on the `android` branch. `main` remains the
upstream reference. Package names, configuration paths (`~/.omp`), and the `omp`
command are preserved.

## Installation

Install Termux, then run:

```sh
pkg update
pkg install curl ca-certificates git jq coreutils
curl -fsSL https://raw.githubusercontent.com/leanmiguel/oh-my-pi-android/android/android/install.sh -o "$TMPDIR/install-omp-android.sh"
sh "$TMPDIR/install-omp-android.sh"
omp --version
omp
```

The installer downloads an Android release with its SHA-256 checksum, checks the
executable before replacing the installed command, and installs to
`~/.local/bin/omp`. Add `~/.local/bin` to your shell's PATH if prompted. Rerun the
same installer to update; `omp update` links to these Android instructions so it
cannot accidentally replace this installation with an upstream Linux build.

Release publication is gated on an ARM64 Termux/Bionic container smoke test.
A successful container test does not replace checking the TUI and provider login
on a physical Android device. Until the first workflow succeeds, no downloadable
Android release is available.

Text clipboard integration is optional: install `termux-api` and the matching
Termux:API Android app. Image clipboard reads and Android desktop automation are
unavailable. The upstream native voice device backend does not support Android.
Existing cloud providers, tools, settings, extensions, and sessions are otherwise
kept in the upstream implementation; provider-specific integrations still need
normal account setup.

## Architecture and maintenance

The standalone executable combines the official Android ARM64 Bun runtime, OMP's
existing TypeScript application, and the Rust N-API addon compiled for
`aarch64-linux-android`. Cross-builds omit JSC bytecode. The addon is embedded and
extracted using upstream's existing version-stamped loader. Native segments use
16 KB page alignment for Android devices with 16 KB pages.

Android changes are restricted to the native loader identity, Termux clipboard
bridge, Android's system shell for command-backed configuration values,
Linux-compatible process primitives with a pidfd fallback, and Android
build/install scripts. Upstream feature implementation and package names stay in
place. Android signalling falls back to a numeric PID when the kernel denies
pidfd access; the start-time check narrows, but cannot remove, the PID-reuse race.
Android also limits process visibility and file access to the app sandbox.

To bring in an upstream update, start from a clean Android checkout:

```sh
git switch android
sh android/sync-upstream.sh --check
sh android/sync-upstream.sh --apply
# Resolve any conflicts, inspect the diff, and run the checks below.
git push origin android
```

The check fetches upstream and uses `git merge-tree` without changing HEAD, the
index, or working files. Applying a merge preserves the upstream commits and the
Android patch history. Nothing automatically merges updates or opens issues/PRs.
The CI workflow builds each Android push, runs the runtime smoke test, and only
publishes a release when those gates succeed. Keep Android patches small and
submit portable fixes upstream when appropriate.

## Build on a Linux x86-64 machine

Use the pinned Rust nightly in `rust-toolchain.toml`, Bun 1.4.3, Android NDK r27d,
C/C++ build tools, CMake, Ninja, and pkg-config. The CI workflow is the complete
reference. The official Bun asset is `bun-linux-aarch64-android.zip`.

```sh
bun install --frozen-lockfile
rustup target add aarch64-linux-android
export ANDROID_NDK_HOME=/path/to/android-ndk-r27d
export OMP_ANDROID_BUN=/path/to/bun-linux-aarch64-android/bun
sh android/build.sh --check
sh android/build.sh
```

Outputs: `android/dist/omp`, `omp-android-arm64.tar.gz`, and `SHA256SUMS`.
The executable includes Bun; no separate runtime or Rust toolchain is needed on
the phone. The build reuses upstream's bundling, docs/stat embedding, and version
stamping rather than maintaining a second application bundle implementation.

For a physical-device smoke test:

```sh
OMP_ANDROID_EXECUTABLE="$HOME/.local/bin/omp" sh android/smoke.sh
```

The smoke probe checks command startup, help, and upstream's worker/tiny-inference
subprocess lifecycle without requiring an API key. Test an authenticated coding
session in a disposable project before relying on the build for daily work.
