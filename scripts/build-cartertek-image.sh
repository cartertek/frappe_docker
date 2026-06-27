#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

image_name="${CUSTOM_IMAGE:-cartertek/frappe}"
primary_tag="${CUSTOM_TAG:-develop}"
custom_tags="${CUSTOM_TAGS:-}"
frappe_path="${FRAPPE_PATH:-https://github.com/frappe/frappe}"
frappe_branch="${FRAPPE_BRANCH:-develop}"
containerfile="${CONTAINERFILE:-images/layered/Containerfile}"

if [[ ! -s apps.json ]]; then
  echo "apps.json is missing or empty" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not on PATH" >&2
  exit 1
fi

if [[ -n "$custom_tags" ]]; then
  read -r -a tags <<<"${custom_tags//,/ }"
else
  tags=("$primary_tag")
  if [[ "$primary_tag" == "develop" ]]; then
    tags+=("latest")
  elif [[ "$primary_tag" =~ ^v([0-9]+)\. ]]; then
    major="${BASH_REMATCH[1]}"
    tags+=("v${major}" "version-${major}")
  fi
fi

unique_tags=()
for candidate in "${tags[@]}"; do
  [[ -n "$candidate" ]] || continue
  seen=false
  for existing in "${unique_tags[@]}"; do
    if [[ "$existing" == "$candidate" ]]; then
      seen=true
      break
    fi
  done
  if [[ "$seen" == false ]]; then
    unique_tags+=("$candidate")
  fi
done

if [[ "${#unique_tags[@]}" -eq 0 ]]; then
  echo "No image tags resolved" >&2
  exit 1
fi

build_tag="${unique_tags[0]}"

echo "Building ${image_name}:${build_tag}"
echo "Frappe: ${frappe_path} @ ${frappe_branch}"
echo "Containerfile: ${containerfile}"
echo "Image tags: ${unique_tags[*]}"

DOCKER_BUILDKIT=1 docker build \
  --build-arg="FRAPPE_PATH=${frappe_path}" \
  --build-arg="FRAPPE_BRANCH=${frappe_branch}" \
  --secret=id=apps_json,src=apps.json \
  --tag="${image_name}:${build_tag}" \
  --file="${containerfile}" .

for alias in "${unique_tags[@]:1}"; do
  docker image tag "${image_name}:${build_tag}" "${image_name}:${alias}"
done

echo "Built ${image_name} with tags: ${unique_tags[*]}"
