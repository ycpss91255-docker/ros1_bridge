#!/usr/bin/env bash

set -euo pipefail

FILE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
    cat >&2 <<'EOF'
Usage: ./build.sh [-h] [TARGET]

Targets:
  runtime  Runtime image (default)
  test     Run smoke tests
EOF
    exit 0
}

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    usage
fi

# Build target: runtime (default), test
TARGET="${1:-runtime}"

docker compose -f "${FILE_PATH}/compose.yaml" build "${TARGET}"
