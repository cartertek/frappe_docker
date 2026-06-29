#!/bin/sh
set -eu

: "${BACKEND_CONTAINER:=frappe-backend-1}"
: "${BACKUP_PATH:=/backup}"
: "${BACKUP_RETENTION_DAYS:=7}"
: "${HOLD_OPEN:=1}"

if [ -n "${SITE_NAME:-}" ]; then
  detected_site="$SITE_NAME"
else
  detected_site=""
fi

echo "Waiting for backend container: ${BACKEND_CONTAINER}"
until docker inspect -f '{{.State.Running}}' "$BACKEND_CONTAINER" 2>/dev/null | grep -q true; do
  sleep 2
done

echo "Waiting for valid Frappe bench directory..."
until docker exec "$BACKEND_CONTAINER" bash -lc 'cd /home/frappe/frappe-bench 2>/dev/null && [ -d apps ] && [ -d sites ] && [ -f sites/common_site_config.json ]'; do
  sleep 2
done

if [ -z "$detected_site" ]; then
  echo "Detecting site name..."
  detected_site="$(docker exec "$BACKEND_CONTAINER" bash -lc "cd /home/frappe/frappe-bench && find sites -mindepth 2 -maxdepth 2 -name site_config.json | sed -E 's#^sites/([^/]+)/site_config.json#\1#' | head -n 1" | tr -d '\r')"
fi

if [ -z "$detected_site" ]; then
  echo "No Frappe site found."
  exit 1
fi

echo "Running Frappe backup for site: ${detected_site}"
docker exec \
  -e SITE_NAME="$detected_site" \
  -e BACKUP_PATH="$BACKUP_PATH" \
  -e BACKUP_RETENTION_DAYS="$BACKUP_RETENTION_DAYS" \
  "$BACKEND_CONTAINER" \
  bash -lc 'cd /home/frappe/frappe-bench && mkdir -p "$BACKUP_PATH" && bench --site "$SITE_NAME" backup --with-files --compress --backup-path "$BACKUP_PATH" && find "$BACKUP_PATH" -type f -mtime +"$BACKUP_RETENTION_DAYS" -delete'

echo "Backup complete."

if [ "$HOLD_OPEN" = "1" ]; then
  echo "Holding backup container open."
  tail -f /dev/null
fi
