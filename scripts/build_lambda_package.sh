#!/usr/bin/env bash
set -euo pipefail

project_dir="$1"
function_name="$2"
src_dir="$project_dir/src/lambda/$function_name"
build_dir="$project_dir/.build/$function_name"

rm -rf "$build_dir"
mkdir -p "$build_dir"

if [[ -f "$src_dir/requirements.txt" ]]; then
  python3 -m pip install --disable-pip-version-check --no-cache-dir \
    --target "$build_dir" -r "$src_dir/requirements.txt"
fi

cp "$src_dir"/*.py "$build_dir"/
