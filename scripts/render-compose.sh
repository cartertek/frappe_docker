#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

env_file="${ENV_FILE:-.env.production}"
output="${OUTPUT:-compose.cartertek.rendered.yaml}"

if [[ ! -f "$env_file" ]]; then
  echo "Missing env file: $env_file" >&2
  echo "Copy .env.production.example to .env.production first." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not on PATH" >&2
  exit 1
fi

docker compose --env-file "$env_file" \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/cartertek.yaml \
  config >"$output"

echo "Rendered $output"
