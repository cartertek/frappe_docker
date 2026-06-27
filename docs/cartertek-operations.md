# Cartertek Frappe Operations

## Build image

```bash
cp .env.production.example .env.production
# edit .env.production
CUSTOM_TAG=v17-frappe-production-$(date +%Y%m%d) scripts/build-cartertek-image.sh
```

The build uses `images/layered/Containerfile` and passes `apps.json` as a BuildKit secret.

## Render compose

```bash
ENV_FILE=.env.production scripts/render-compose.sh
```

This writes `compose.cartertek.rendered.yaml` for inspection.

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
SITE_NAME=hrms.localhost BACKUP_DIR=/path/to/pre-migration-backup scripts/restore-site.sh
```

Then migrate and validate:

```bash
SITE_NAME=hrms.localhost scripts/migrate-site.sh
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
