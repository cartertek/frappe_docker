# Cartertek Migration Plan

This repository branch prepares the move from the current HRMS bootstrap-style Docker stack to a production stack based on the Cartertek fork of `frappe_docker`.

## Target

The target image is:

```text
cartertek/erpnext:<pinned tag>
```

The image should contain:

```text
frappe
erpnext
hrms
sales_engagement_intelligence
```

The target stack should use the official split-service compose structure:

```text
backend
frontend
websocket
queue-short
queue-long
scheduler
db
redis-cache
redis-queue
```

## Branch contents

This branch adds Cartertek-specific deployment material only:

```text
apps.json
.env.example
.env.production.example
overrides/cartertek.yaml
scripts/audit-current-stack.sh
scripts/backup-current-stack.sh
scripts/build-cartertek-image.sh
scripts/render-compose.sh
scripts/restore-site.sh
scripts/migrate-site.sh
docs/cartertek-migration-plan.md
docs/cartertek-operations.md
```

It intentionally avoids modifying upstream `compose.yaml`, `docker-bake.hcl`, `images/*`, or official override files.

## Initial sequence

1. Copy `.env.production.example` to `.env.production` and set real secrets and port choices.
2. Build the image with `scripts/build-cartertek-image.sh`.
3. Render and inspect compose with `scripts/render-compose.sh`.
4. Audit the current stack with `scripts/audit-current-stack.sh`.
5. Back up the current stack with `scripts/backup-current-stack.sh`.
6. Start the new stack with fresh persistent volumes.
7. Restore the site with `scripts/restore-site.sh`.
8. Migrate and validate with `scripts/migrate-site.sh`.

## Cutover caution

Do not delete the old stack or old volumes until the new stack is accepted. The old stack is the rollback path.
