#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from urllib.parse import urlparse

apps_json = sys.argv[1]
bench_path = sys.argv[2]

with open(apps_json) as f:
    apps = json.load(f)

for app in apps:
    pin = app.get("pin")
    if not pin:
        continue

    repo_name = app.get("name")
    if not repo_name:
        repo_name = os.path.splitext(os.path.basename(urlparse(app["url"]).path))[0]

    app_dir_name = repo_name
    if repo_name == "frappe-sales-engagement-intelligence":
        app_dir_name = "sales_engagement_intelligence"

    app_path = os.path.join(bench_path, "apps", app_dir_name)
    if not os.path.isdir(app_path):
        raise SystemExit(f"Pinned app path does not exist: {app_path}")

    subprocess.check_call(
        ["git", "-C", app_path, "fetch", "--depth", "1", "upstream", pin]
    )
    subprocess.check_call(
        ["git", "-C", app_path, "checkout", "--force", "--detach", pin]
    )
