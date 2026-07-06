#!/bin/sh
set -eu

BENCH_PATH=${1:-/home/frappe/frappe-bench}
PATCH_DIR=${2:-/tmp/build-patches}
REBUILD_FILE="$PATCH_DIR/rebuild-apps.txt"

if [ ! -d "$PATCH_DIR" ]; then
  echo "No build patch directory found: $PATCH_DIR"
  exit 0
fi

cd "$BENCH_PATH"

find "$PATCH_DIR" -type f -name "*.patch" | sort | while IFS= read -r patch_file; do
  echo "Applying build patch: $patch_file"
  git apply --check "$patch_file"
  git apply "$patch_file"
done

if [ -f "$REBUILD_FILE" ]; then
  while IFS= read -r app; do
    case "$app" in
    "" | "#"*) continue ;;
    esac
    echo "Rebuilding patched app assets: $app"
    bench build --app "$app"
  done <"$REBUILD_FILE"
fi
