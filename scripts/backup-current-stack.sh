#!/usr/bin/env bash
set -euo pipefail

site="${SITE_NAME:-hrms.localhost}"
target_container="${TARGET_CONTAINER:-erpnext-frappe}"
out_dir="${OUT_DIR:-$PWD/backups/pre-migration-$(date +%Y%m%d-%H%M%S)}"
bench_dir="${BENCH_DIR:-/home/frappe/frappe-bench}"

mkdir -p "$out_dir"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required on the host running the old stack" >&2
  exit 1
fi

echo "Auditing current stack in container ${target_container} for site ${site}"
docker exec "$target_container" bash -lc "cd '$bench_dir' && bench --site '$site' list-apps" | tee "$out_dir/list-apps.txt"
docker exec "$target_container" bash -lc "cd '$bench_dir' && bench version" | tee "$out_dir/bench-version.txt"
docker exec "$target_container" bash -lc "cd '$bench_dir' && bench --site '$site' execute frappe.is_setup_complete" | tee "$out_dir/is-setup-complete.txt"
docker exec "$target_container" bash -lc "cd '$bench_dir' && bench --site '$site' execute frappe.get_all --args '[\"Company\"]' --kwargs '{\"fields\":[\"name\",\"abbr\",\"default_currency\"]}'" | tee "$out_dir/company.txt"

docker exec "$target_container" bash -lc "cd '$bench_dir' && bench --site '$site' backup --with-files"

latest_backup_dir="$(docker exec "$target_container" bash -lc "cd '$bench_dir/sites/$site/private/backups' && pwd")"
mapfile -t artifacts < <(docker exec "$target_container" bash -lc "find '$bench_dir/sites/$site/private/backups' -maxdepth 1 -type f -printf '%T@ %p\n' | sort -nr | head -n 10 | cut -d' ' -f2-")

printf '%s\n' "${artifacts[@]}" >"$out_dir/backup-artifacts-in-container.txt"

for path in \
  "$bench_dir/sites/$site/site_config.json" \
  "$bench_dir/sites/common_site_config.json" \
  "$bench_dir/sites/apps.txt"; do
  docker cp "${target_container}:${path}" "$out_dir/" || true
done

for artifact in "${artifacts[@]}"; do
  docker cp "${target_container}:${artifact}" "$out_dir/"
done

cat >"$out_dir/README.txt" <<README
Pre-migration backup for ${site}
Container: ${target_container}
Bench: ${bench_dir}
Container backup dir: ${latest_backup_dir}
Created: $(date -Is)

Validate that this directory includes:
- database sql.gz
- public files tar
- private files tar
- site_config.json
- common_site_config.json
- apps.txt
README

echo "Backup copied to $out_dir"
