#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

env_file="${ENV_FILE:-.env.production}"
output="${OUTPUT:-}"

if [[ ! -f "$env_file" ]]; then
  echo "Missing env file: $env_file" >&2
  echo "Copy .env.production.example to .env.production first." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed or not on PATH" >&2
  exit 1
fi

compose_args=(
  --env-file "$env_file"
  -f compose.yaml
  -f overrides/compose.mariadb.yaml
  -f overrides/compose.redis.yaml
  -f overrides/compose.noproxy.yaml
  -f overrides/cartertek.yaml
  -f overrides/compose.backup-on-start.yaml
)

if [[ -n "${TAILNET_MCP_SERVICES:-}" ]]; then
  raw_tailnet_services="${TAILNET_MCP_SERVICES}"
  tailnet_services=",${raw_tailnet_services},"
  IFS=',' read -r -a requested_tailnet_services <<<"$raw_tailnet_services"
  for tailnet_service in "${requested_tailnet_services[@]}"; do
    case "$tailnet_service" in
    backend | frontend | websocket | queue-short | queue-long | scheduler) ;;
    "") ;;
    *)
      echo "Unsupported TAILNET_MCP_SERVICES entry: $tailnet_service" >&2
      echo "Supported values: backend,frontend,websocket,queue-short,queue-long,scheduler" >&2
      exit 1
      ;;
    esac
  done

  export TAILNET_MCP_ENABLE_BACKEND=false
  export TAILNET_MCP_ENABLE_FRONTEND=false
  export TAILNET_MCP_ENABLE_WEBSOCKET=false
  export TAILNET_MCP_ENABLE_QUEUE_SHORT=false
  export TAILNET_MCP_ENABLE_QUEUE_LONG=false
  export TAILNET_MCP_ENABLE_SCHEDULER=false

  [[ "$tailnet_services" == *",backend,"* ]] && export TAILNET_MCP_ENABLE_BACKEND=true
  [[ "$tailnet_services" == *",frontend,"* ]] && export TAILNET_MCP_ENABLE_FRONTEND=true
  [[ "$tailnet_services" == *",websocket,"* ]] && export TAILNET_MCP_ENABLE_WEBSOCKET=true
  [[ "$tailnet_services" == *",queue-short,"* ]] && export TAILNET_MCP_ENABLE_QUEUE_SHORT=true
  [[ "$tailnet_services" == *",queue-long,"* ]] && export TAILNET_MCP_ENABLE_QUEUE_LONG=true
  [[ "$tailnet_services" == *",scheduler,"* ]] && export TAILNET_MCP_ENABLE_SCHEDULER=true

  compose_args+=(-f overrides/compose.tailnet-mcp-gateway.yaml)
fi

compose_args+=(config)

if [[ -z "$output" || "$output" == "-" ]]; then
  docker compose "${compose_args[@]}"
else
  docker compose "${compose_args[@]}" >"$output"
  echo "Rendered $output"
fi
