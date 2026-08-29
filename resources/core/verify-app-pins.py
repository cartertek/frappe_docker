#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from urllib.parse import urlparse


def repo_name(app):
    name = app.get("name")
    if name:
        return name
    return os.path.splitext(os.path.basename(urlparse(app["url"]).path))[0]


def app_dir_name(name):
    if name == "frappe-sales-engagement-intelligence":
        return "sales_engagement_intelligence"
    return name


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify-app-pins.py <apps.json> <bench-path>")

    apps_json, bench_path = sys.argv[1:]
    with open(apps_json) as f:
        apps = json.load(f)

    for app in apps:
        pin = app.get("pin")
        if not pin:
            continue

        name = repo_name(app)
        app_path = os.path.join(bench_path, "apps", app_dir_name(name))
        if not os.path.isdir(app_path):
            raise SystemExit(f"Pinned app path does not exist: {app_path}")

        actual = subprocess.check_output(
            ["git", "-C", app_path, "rev-parse", "HEAD"], text=True
        ).strip()
        if actual != pin:
            raise SystemExit(f"Pinned app {name} resolved to {actual}, expected {pin}")
        print(f"Verified {name} at {pin}")


if __name__ == "__main__":
    main()
