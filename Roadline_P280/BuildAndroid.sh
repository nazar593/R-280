#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -ne 1 || ! -x "$1" ]]; then
    printf 'Usage: %s /path/to/Unity\n' "$0" >&2
    exit 2
fi
unity_executable="$(realpath -- "$1")"
"$unity_executable" -batchmode -nographics -quit -projectPath "$project_dir" -buildTarget Android \
    -executeMethod Roadline.Editor.RoadlineBuild.BuildAndroid -logFile "$project_dir/android-build.log"
test -s "$project_dir/Builds/Roadline-P280.apk"
