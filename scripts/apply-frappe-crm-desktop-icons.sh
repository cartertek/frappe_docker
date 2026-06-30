#!/usr/bin/env bash
set -euo pipefail

site="${SITE_NAME:-frappe.localhost}"
project="${COMPOSE_PROJECT_NAME:-frappe}"
backend="${BACKEND_CONTAINER:-${project}-backend-1}"
frontend="${FRONTEND_CONTAINER:-${project}-frontend-1}"
asset_dir="${CRM_DESKTOP_ICON_ASSET_DIR:-frappe_crm_desktop_icons}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/resources/cartertek/frappe-crm-desktop-icons"

if [[ ! -d "$source_dir" ]]; then
  echo "Missing icon source directory: $source_dir" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

for container in "$backend" "$frontend"; do
  if ! docker ps --format '{{.Names}}' | grep -Fxq "$container"; then
    echo "Container not running or not found: $container" >&2
    exit 1
  fi
done

for container in "$backend" "$frontend"; do
  docker exec -u frappe "$container" bash -lc "mkdir -p '/home/frappe/frappe-bench/assets/$asset_dir'"
  docker cp "$source_dir/." "$container:/home/frappe/frappe-bench/assets/$asset_dir/"
  docker exec -u frappe "$container" bash -lc "chmod 0644 '/home/frappe/frappe-bench/assets/$asset_dir/'*.svg"
done

tmp_py="$(mktemp)"
cat > "$tmp_py" <<'PY'
import json
import os

asset_dir = os.environ.get("CRM_DESKTOP_ICON_ASSET_DIR", "frappe_crm_desktop_icons")
asset_prefix = f"/assets/{asset_dir}"

children = [
    ("Dashboard", "/crm/dashboard", "crm_dashboard.svg", "layout-dashboard", 1),
    ("Leads", "/crm/leads", "crm_leads.svg", "users", 2),
    ("Deals", "/crm/deals", "crm_deals.svg", "handshake", 3),
    ("Contacts", "/crm/contacts", "crm_contacts.svg", "square-user-round", 4),
    ("Organizations", "/crm/organizations", "crm_organizations.svg", "organization", 5),
    ("Notes", "/crm/notes", "crm_notes.svg", "file-text", 6),
    ("Tasks", "/crm/tasks", "crm_tasks.svg", "check-square", 7),
]

parent = frappe.get_doc("Desktop Icon", "Frappe CRM") if frappe.db.exists("Desktop Icon", "Frappe CRM") else frappe.new_doc("Desktop Icon")
parent.label = "Frappe CRM"
parent.icon_type = "App"
parent.link_type = "External"
parent.link = "/crm"
parent.link_to = None
parent.parent_icon = None
parent.app = "crm"
parent.logo_url = "/assets/crm/images/logo.svg"
parent.bg_color = "gray"
parent.hidden = 0
parent.standard = 0
parent.restrict_removal = 0
parent.idx = parent.idx or 0
if parent.is_new():
    parent.insert(ignore_permissions=True)
else:
    parent.save(ignore_permissions=True)

for label, route, filename, icon_name, idx in children:
    sidebar = frappe.get_doc("Workspace Sidebar", label) if frappe.db.exists("Workspace Sidebar", label) else frappe.new_doc("Workspace Sidebar")
    sidebar.title = label
    sidebar.app = "crm"
    sidebar.header_icon = icon_name
    sidebar.standard = 0
    sidebar.set("items", [])
    sidebar.append(
        "items",
        {
            "type": "Link",
            "label": label,
            "link_type": "URL",
            "url": route,
            "icon": icon_name,
            "collapsible": 1,
            "show_arrow": 0,
            "indent": 0,
            "child": 0,
            "keep_closed": 0,
        },
    )
    if sidebar.is_new():
        sidebar.insert(ignore_permissions=True)
    else:
        sidebar.save(ignore_permissions=True)

    icon = frappe.get_doc("Desktop Icon", label) if frappe.db.exists("Desktop Icon", label) else frappe.new_doc("Desktop Icon")
    icon.label = label
    icon.icon_type = "Link"
    icon.link_type = "Workspace Sidebar"
    icon.link_to = label
    icon.link = None
    icon.parent_icon = "Frappe CRM"
    icon.app = "crm"
    icon.idx = idx
    icon.icon = icon_name
    icon.logo_url = f"{asset_prefix}/{filename}"
    icon.bg_color = "gray"
    icon.hidden = 0
    icon.standard = 0
    icon.restrict_removal = 0
    if icon.is_new():
        icon.insert(ignore_permissions=True)
    else:
        icon.save(ignore_permissions=True)

frappe.db.commit()

fields = [
    "name",
    "label",
    "bg_color",
    "link",
    "link_type",
    "app",
    "icon_type",
    "parent_icon",
    "icon",
    "link_to",
    "idx",
    "standard",
    "logo_url",
    "hidden",
    "restrict_removal",
    "icon_image",
]
crm_names = {"Frappe CRM", *(label for label, *_ in children)}
crm_records = frappe.get_all("Desktop Icon", filters={"name": ["in", list(crm_names)]}, fields=fields)
crm_items = {record["name"]: dict(record) for record in crm_records}
for item in crm_items.values():
    item["child_icons"] = []
    item["in_folder"] = bool(item.get("parent_icon"))
crm_items["Frappe CRM"]["hidden"] = 0
crm_items["Frappe CRM"]["child_icons"] = [crm_items[label] for label, *_ in children if label in crm_items]

for layout_name in frappe.get_all("Desktop Layout", pluck="name"):
    layout_doc = frappe.get_doc("Desktop Layout", layout_name)
    try:
        layout = json.loads(layout_doc.layout or "[]")
        if not isinstance(layout, list):
            layout = []
    except Exception:
        layout = []

    filtered = [item for item in layout if item.get("name") not in crm_names and item.get("label") not in crm_names]
    filtered.append(crm_items["Frappe CRM"])
    for label, *_ in children:
        if label in crm_items:
            filtered.append(crm_items[label])
    layout_doc.layout = json.dumps(filtered)
    layout_doc.save(ignore_permissions=True)

frappe.db.commit()
for user in frappe.get_all("Desktop Layout", pluck="name"):
    frappe.clear_cache(user=user)

print("Frappe CRM desktop icons applied")
PY

docker cp "$tmp_py" "$backend:/tmp/apply-frappe-crm-desktop-icons.py"
rm -f "$tmp_py"
docker exec \
  -u frappe \
  -e CRM_DESKTOP_ICON_ASSET_DIR="$asset_dir" \
  "$backend" \
  bash -lc "cd /home/frappe/frappe-bench && printf 'exec(open(\"/tmp/apply-frappe-crm-desktop-icons.py\").read())\\nexit()\\n' | bench --site '$site' console"

echo "Frappe CRM desktop customization applied for site $site."
