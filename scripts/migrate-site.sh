#!/usr/bin/env bash
set -euo pipefail

site="${SITE_NAME:-hrms.localhost}"
project="${COMPOSE_PROJECT_NAME:-frappe_docker}"
container="${BACKEND_CONTAINER:-${project}-backend-1}"

docker exec "$container" bash -lc "cd /home/frappe/frappe-bench && bench --site '$site' migrate"
docker exec "$container" bash -lc "cd /home/frappe/frappe-bench && bench --site '$site' clear-cache"
docker exec "$container" bash -lc "cd /home/frappe/frappe-bench && bench --site '$site' list-apps"
docker exec "$container" bash -lc "cd /home/frappe/frappe-bench && bench --site '$site' execute frappe.is_setup_complete"
docker exec "$container" bash -lc "cd /home/frappe/frappe-bench && bench --site '$site' execute frappe.get_all --args '[\"Company\"]' --kwargs '{\"fields\":[\"name\",\"abbr\",\"default_currency\"]}'"
