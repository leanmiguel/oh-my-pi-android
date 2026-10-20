Native Android ARM64 build for Termux, based on upstream OMP.

Download `omp-android-arm64.tar.gz` and `SHA256SUMS`, or follow
[the Android installation instructions](https://github.com/leanmiguel/oh-my-pi-android/blob/android/ANDROID.md).

The executable includes the official Android Bun runtime and an Android/Bionic
native addon. No Rust compilation or Bun installation is required on the phone.
Release publication requires the ARM64 Termux container smoke test to pass.
Physical-device TUI and authenticated provider sessions require a device check.

Text clipboard integration requires Termux:API. Image clipboard, Android desktop
automation, and native voice devices are unavailable.
