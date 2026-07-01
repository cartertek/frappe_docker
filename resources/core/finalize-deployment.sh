#!/usr/bin/env bash
set -euo pipefail

if [[ "${FINALIZE_DEPLOYMENT_ON_START:-true}" != "true" ]]; then
  echo "[finalize-deployment] Disabled by FINALIZE_DEPLOYMENT_ON_START"
  exit 0
fi

bench_dir="/home/frappe/frappe-bench"
site="${SITE_NAME:-${FRAPPE_SITE_NAME_HEADER:-frappe.localhost}}"
token_dir="${FINALIZE_DEPLOYMENT_TOKEN_DIR:-/home/frappe/.cache/cartertek}"
token_file="$token_dir/finalize-deployment.done"
site_config="$bench_dir/sites/$site/site_config.json"

if [[ -f "$token_file" ]]; then
  echo "[finalize-deployment] Already finalized for this container"
  exit 0
fi

if [[ ! -f "$site_config" ]]; then
  echo "[finalize-deployment] Site config not found for $site; skipping"
  mkdir -p "$token_dir"
  printf 'skipped: missing site config for %s\n' "$site" >"$token_file"
  exit 0
fi

cd "$bench_dir"

echo "[finalize-deployment] Finalizing site $site"
bench --site "$site" migrate
bench --site "$site" clear-cache
bench --site "$site" clear-website-cache

mkdir -p "$token_dir"
{
  printf 'site=%s\n' "$site"
  printf 'finalized_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$token_file"

echo "[finalize-deployment] Complete"
