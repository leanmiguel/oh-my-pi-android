#!/bin/sh
set -eu
: "${OMP_ANDROID_EXECUTABLE:?Set OMP_ANDROID_EXECUTABLE to the installed Android omp executable}"
"$OMP_ANDROID_EXECUTABLE" --version
"$OMP_ANDROID_EXECUTABLE" --help >/dev/null
"$OMP_ANDROID_EXECUTABLE" stats --help >/dev/null
"$OMP_ANDROID_EXECUTABLE" --smoke-test
