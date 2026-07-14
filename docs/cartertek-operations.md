# Cartertek Frappe Operations

## Build image

```bash
cp .env.production.example .env.production
# edit .env.production
CUSTOM_TAG=v17.x.y scripts/build-cartertek-image.sh
```

The build intentionally uses `images/layered/Containerfile` as the final production image path. This is the upstream Frappe Docker custom-app workflow for production builds that reuse Frappe-managed base/build layers while installing ERPNext, HRMS, Frappe CRM, and Cartertek apps from `apps.json`. Image tags mirror upstream Frappe Docker aliases: `develop` also tags `latest`; an exact release such as `v17.x.y` also tags `v17` and `version-17`.

## Image tag convention

Use `CUSTOM_TAG` for the primary image tag. Leave `CUSTOM_TAGS` empty to derive upstream-style aliases automatically.

```bash
CUSTOM_TAG=develop scripts/build-cartertek-image.sh
# tags: develop latest

CUSTOM_TAG=v17.x.y scripts/build-cartertek-image.sh
# tags: v17.x.y v17 version-17
```

Use `CUSTOM_TAGS` only when an explicit tag set is required.

## GitHub Actions image publish

The PR includes `.github/workflows/cartertek-build-image.yml`. On pull requests it builds and smoke-tests the layered image without publishing. On pushes to `main`, or manual dispatch with publishing enabled, it publishes to GHCR as `ghcr.io/cartertek/frappe`. Tag aliases mirror upstream Frappe Docker: `develop` also publishes `latest`; an exact tag like `v17.x.y` also publishes `v17` and `version-17`.

## Render compose

```bash
ENV_FILE=.env.production scripts/render-compose.sh
```

This writes `compose.cartertek.rendered.yaml` for inspection.

## Local site name

The target stack defaults to `SITE_NAME=frappe.localhost` and `FRAPPE_SITE_NAME_HEADER=frappe.localhost`. This is intentional for the current laptop-hosted deployment. The default noproxy mapping uses host port `9880` so it does not conflict with the old stack on `9800`, but it points to the Frappe Docker `frontend` service on container port `8080`, not directly to the backend bench server on `8000`. Because the site header is fixed to `frappe.localhost`, the frontend can route laptop requests to the intended site even when the browser uses the forwarded Docker port. The old source site remains `hrms.localhost` only for audit and backup scripts. Restore and migrate scripts default to the new `frappe.localhost` site. Access the new stack at `http://localhost:9880` or `http://frappe.localhost:9880`.

## Start production stack

```bash
docker compose --env-file .env.production \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.noproxy.yaml \
  -f overrides/cartertek.yaml \
  up -d
```

## Audit old stack

Run from a Docker host that can access the old `erpnext-frappe` container:

```bash
SITE_NAME=hrms.localhost TARGET_CONTAINER=erpnext-frappe scripts/audit-current-stack.sh
```

## Back up old stack

```bash
SITE_NAME=hrms.localhost TARGET_CONTAINER=erpnext-frappe scripts/backup-current-stack.sh
```

Confirm the output directory contains:

```text
*.sql.gz
*public-files.tar
*private-files.tar
site_config.json
common_site_config.json
apps.txt
```

## Restore into new stack

Create the site first if needed, then restore the database and files:

```bash
SITE_NAME=frappe.localhost BACKUP_DIR=/path/to/pre-migration-backup scripts/restore-site.sh
```

Then migrate and validate:

```bash
SITE_NAME=frappe.localhost scripts/migrate-site.sh
```

## Update image later

1. Update `apps.json` branches/tags/commits.
2. Build a new pinned image tag.
3. Update `.env.production` `CUSTOM_TAG`.
4. Recreate services.
5. Run migration.

## Sync fork with upstream

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

Use pull requests for Cartertek deployment changes because the fork protects `main`.

## Optional Tailnet MCP Gateway access

The Cartertek layered image clones the Tailnet MCP Gateway `master` branch during
the image build and copies only its `machine-tools` directory into the final
image. These tools were previously installed into a running container with
`tailnet-mcp-gateway/machine-tools/inject.sh`.

The image build now handles the install portion:

- OpenSSH server is installed.
- Tailscale is installed.
- `/usr/local/lib/machine-tools` contains the gateway machine-tools scripts.
- `/usr/local/bin/machine-tools-start.sh` starts `sshd` and `tailscaled`.
- The normal image entrypoint calls `/usr/local/bin/machine-tools-container-start.sh`
  before starting the app command.

Runtime configuration is supplied through
`overrides/compose.tailnet-mcp-gateway.yaml`. To include that override in the
Cartertek render script, provide a non-empty `TAILNET_MCP_SERVICES` list.

Examples:

```bash
TAILNET_MCP_SERVICES=backend
TAILNET_MCP_SERVICES=backend,queue-short,scheduler
```

Leave `TAILNET_MCP_SERVICES` blank to disable the override.

The render script turns that service list into per-service enable flags for the
known Frappe services: `backend`, `frontend`, `websocket`, `queue-short`,
`queue-long`, and `scheduler`. The compose override attaches the shared machine
tools environment to those services, but the entrypoint hook only runs where the
rendered per-service flag is true. It does not set `container_name:`. Instead,
it passes the Compose-generated default container name pattern, such as
`${COMPOSE_PROJECT_NAME:-frappe}-backend-1`, into the container as
`TAILNET_MCP_CONTAINER_NAME`.

Set the runtime credentials and SSH key source:

```bash
TAILSCALE_API_KEY=tskey-api-...
TAILNET_MCP_SSH_HOST_DIR=./ssh
```

SSH keys are provided by mounting a host directory containing `.pub` files with
`TAILNET_MCP_SSH_HOST_DIR`. This mounted directory is the Docker-native
replacement for the old injector copying the repository `ssh` directory into the
container.

On startup, each enabled container starts SSH and Tailscale, writes authorized
keys from the mounted SSH directory, and uses
`TAILSCALE_API_KEY` to log the container into the tailnet when it is not already
authenticated.
