#!/usr/bin/env bash
set -euo pipefail

site="${SITE_NAME:-hrms.localhost}"
target_container="${TARGET_CONTAINER:-erpnext-frappe}"
bench_dir="${BENCH_DIR:-/home/frappe/frappe-bench}"
out_dir="${OUT_DIR:-$PWD/audits/current-stack-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$out_dir"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required on the host running the old stack" >&2
  exit 1
fi

run() {
  local name="$1"
  shift
  echo "== $name ==" | tee "$out_dir/$name.txt"
  docker exec "$target_container" bash -lc "cd '$bench_dir' && $*" | tee -a "$out_dir/$name.txt"
}

run list-apps "bench --site '$site' list-apps"
run bench-version "bench version"
run setup-complete "bench --site '$site' execute frappe.is_setup_complete"
run doctor "bench --site '$site' doctor"
run company "bench --site '$site' execute frappe.get_all --args '[\"Company\"]' --kwargs '{\"fields\":[\"name\",\"abbr\",\"default_currency\"]}'"

docker exec "$target_container" bash -lc "cd '$bench_dir/apps/sales_engagement_intelligence' && git status --short --branch && git rev-parse HEAD" > "$out_dir/sales-engagement-intelligence-git.txt" || true

docker exec "$target_container" bash -lc "pid=\$(pgrep -f 'frappe serve --port 8000' | head -n1); if [ -n \"\$pid\" ]; then readlink /proc/\$pid/cwd; else echo 'frappe serve process not found'; fi" > "$out_dir/active-serving-path.txt" || true

echo "Audit written to $out_dir"
