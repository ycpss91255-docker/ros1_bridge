#!/usr/bin/env bash

set -euo pipefail

FILE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Parse arguments
DETACH=false
TARGET="runtime"

usage() {
    cat >&2 <<'EOF'
Usage: ./run.sh [-h] [-d|--detach] [TARGET]

Options:
  -h, --help     Show this help
  -d, --detach   Run in background (docker compose up -d)

Targets:
  runtime  Runtime container (default)
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -d|--detach)
            DETACH=true
            shift
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

if [[ "${DETACH}" == true ]]; then
    docker compose -f "${FILE_PATH}/compose.yaml" down 2>/dev/null || true
    docker compose -f "${FILE_PATH}/compose.yaml" up -d "${TARGET}"
else
    docker compose -f "${FILE_PATH}/compose.yaml" run --rm "${TARGET}" "$@"
fi
