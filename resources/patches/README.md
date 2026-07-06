# Build patches

Put image-build patches here as standalone `*.patch` files. The layered image
build copies this directory into the builder stage and applies every patch in
lexicographic order from the bench root after app commit pins are applied.

Patch paths should be relative to `/home/frappe/frappe-bench`, for example:

```diff
--- a/apps/crm/frontend/src/components/Apps.vue
+++ b/apps/crm/frontend/src/components/Apps.vue
```

If a patch changes frontend assets for an app, add that app name to
`rebuild-apps.txt` so the Docker build rebuilds its assets after patching.
