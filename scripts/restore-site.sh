#!/usr/bin/env bash
set -euo pipefail

site="${SITE_NAME:-frappe.localhost}"
project="${COMPOSE_PROJECT_NAME:-frappe}"
container="${BACKEND_CONTAINER:-${project}-backend-1}"
backup_dir="${BACKUP_DIR:-}"
admin_password="${ADMIN_PASSWORD:-admin}"
db_password="${DB_PASSWORD:-}"

if [[ -z "$backup_dir" || ! -d "$backup_dir" ]]; then
  echo "Set BACKUP_DIR to a directory containing the bench backup artifacts." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

if ! docker ps --format "{{.Names}}" | grep -Fxq "$container"; then
  echo "Backend container not running or not found: $container" >&2
  echo "Set COMPOSE_PROJECT_NAME or BACKEND_CONTAINER if needed." >&2
  exit 1
fi

if [[ -z "$db_password" && -f .env.production ]]; then
  db_password="$(awk -F= '$1 == "DB_PASSWORD" {print substr($0, index($0, "=") + 1)}' .env.production | tail -n 1)"
fi

if [[ -z "$db_password" ]]; then
  echo "Set DB_PASSWORD or run from a directory containing .env.production." >&2
  exit 1
fi
db_file="$(find "$backup_dir" -maxdepth 1 -type f \( -name "*database.sql.gz" -o -name "*.sql.gz" \) | sort | tail -n 1)"
public_file="$(find "$backup_dir" -maxdepth 1 -type f \( -name "*public-files.tar" -o -name "*public*.tar" \) | sort | tail -n 1 || true)"
private_file="$(find "$backup_dir" -maxdepth 1 -type f \( -name "*private-files.tar" -o -name "*private*.tar" \) | sort | tail -n 1 || true)"

if [[ -z "$db_file" ]]; then
  echo "No database .sql.gz backup found in $backup_dir" >&2
  exit 1
fi

site_config_path="/home/frappe/frappe-bench/sites/$site/site_config.json"
if ! docker exec "$container" bash -lc "test -f \"$site_config_path\""; then
  echo "Creating target site $site in $container"
  docker exec \
    -e DB_PASSWORD="$db_password" \
    -e ADMIN_PASSWORD="$admin_password" \
    "$container" \
    bash -lc "cd /home/frappe/frappe-bench && bench new-site '$site' --mariadb-user-host-login-scope=% --db-root-password \\\"\\$DB_PASSWORD\\\" --admin-password \\\"\\$ADMIN_PASSWORD\\\""
fi
restore_root="/home/frappe/frappe-bench/sites/${site}/private/backups/manual-restore"
docker exec "$container" bash -lc "mkdir -p '$restore_root'"
docker cp "$db_file" "${container}:${restore_root}/$(basename "$db_file")"

restore_cmd="bench --site '$site' restore '${restore_root}/$(basename "$db_file")' --force"

if [[ -n "$public_file" ]]; then
  docker cp "$public_file" "${container}:${restore_root}/$(basename "$public_file")"
  restore_cmd="$restore_cmd --with-public-files '${restore_root}/$(basename "$public_file")'"
fi

if [[ -n "$private_file" ]]; then
  docker cp "$private_file" "${container}:${restore_root}/$(basename "$private_file")"
  restore_cmd="$restore_cmd --with-private-files '${restore_root}/$(basename "$private_file")'"
fi

echo "Restoring site ${site} in ${container}"
docker exec "$container" bash -lc "cd /home/frappe/frappe-bench && $restore_cmd"

echo "Restore completed. Run scripts/migrate-site.sh next."
