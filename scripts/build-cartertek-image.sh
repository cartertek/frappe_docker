#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

image_name="${CUSTOM_IMAGE:-cartertek/erpnext}"
tag="${CUSTOM_TAG:-v17-hrms-outreach-$(date +%Y%m%d)}"
frappe_path="${FRAPPE_PATH:-https://github.com/frappe/frappe}"
frappe_branch="${FRAPPE_BRANCH:-version-17}"
containerfile="${CONTAINERFILE:-images/layered/Containerfile}"

if [[ ! -s apps.json ]]; then
  echo "apps.json is missing or empty" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not on PATH" >&2
  exit 1
fi

echo "Building ${image_name}:${tag}"
echo "Frappe: ${frappe_path} @ ${frappe_branch}"
echo "Containerfile: ${containerfile}"

DOCKER_BUILDKIT=1 docker build \
  --build-arg="FRAPPE_PATH=${frappe_path}" \
  --build-arg="FRAPPE_BRANCH=${frappe_branch}" \
  --secret=id=apps_json,src=apps.json \
  --tag="${image_name}:${tag}" \
  --file="${containerfile}" .

echo "Built ${image_name}:${tag}"
