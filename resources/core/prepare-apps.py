#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
from urllib.parse import urlparse


def repo_name(app):
    name = app.get("name")
    if name:
        return name
    return os.path.splitext(os.path.basename(urlparse(app["url"]).path))[0]


def run(*args):
    subprocess.check_call(args)


def prepare_pinned_repo(app, root):
    pin = app["pin"]
    name = repo_name(app)
    destination = os.path.join(root, name)
    ref = f"cartertek-pin-{pin[:12]}"

    shutil.rmtree(destination, ignore_errors=True)
    os.makedirs(destination, exist_ok=True)
    run("git", "-C", destination, "init", "--quiet")
    run("git", "-C", destination, "remote", "add", "origin", app["url"])
    run("git", "-C", destination, "fetch", "--depth", "1", "origin", pin)
    run("git", "-C", destination, "checkout", "--quiet", "--detach", "FETCH_HEAD")
    run("git", "-C", destination, "branch", "--force", ref, pin)

    prepared = dict(app)
    prepared["url"] = destination
    prepared["branch"] = ref
    return prepared


def main():
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: prepare-apps.py <apps.json> <prepared-apps.json> <checkout-root>"
        )

    source_path, output_path, checkout_root = sys.argv[1:]
    with open(source_path) as f:
        apps = json.load(f)

    shutil.rmtree(checkout_root, ignore_errors=True)
    os.makedirs(checkout_root, exist_ok=True)

    prepared_apps = []
    for app in apps:
        if app.get("pin"):
            prepared_apps.append(prepare_pinned_repo(app, checkout_root))
        else:
            prepared_apps.append(dict(app))

    with open(output_path, "w") as f:
        json.dump(prepared_apps, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
