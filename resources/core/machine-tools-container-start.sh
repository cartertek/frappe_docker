#!/usr/bin/env bash
set -euo pipefail

[[ "${TAILNET_MCP_GATEWAY_ENABLED:-false}" == "true" ]] || exit 0

marker=/home/frappe/.local/state/tailnet-mcp-gateway/configured

if [[ ! -e "$marker" ]]; then
  : "${TAILSCALE_API_KEY:?TAILSCALE_API_KEY is required}"
  : "${TAILNET_MCP_CONTAINER_NAME:?TAILNET_MCP_CONTAINER_NAME is required}"

  /usr/local/share/tailnet-mcp-gateway/machine-tools/configure.sh \
    --tailscale-api-key "$TAILSCALE_API_KEY" \
    --tailscale-hostname "$TAILNET_MCP_CONTAINER_NAME"

  mkdir -p "$(dirname "$marker")"
  touch "$marker"
fi

/usr/local/bin/machine-tools-start-hook.sh
