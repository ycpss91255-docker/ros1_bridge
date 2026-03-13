#!/usr/bin/env bash

set -euo pipefail

FILE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    cat <<'EOF'
Usage: ./exec.sh [-h] [TARGET] [CMD...]

Arguments:
  TARGET   Service name (default: runtime)
  CMD      Command to execute (default: bash)

Examples:
  ./exec.sh              # Enter runtime container with bash
  ./exec.sh runtime      # Same as above
  ./exec.sh runtime bash # Same as above
EOF
    exit 0
fi

TARGET="${1:-runtime}"
shift 2>/dev/null || true
CMD="${*:-bash}"

docker compose -f "${FILE_PATH}/compose.yaml" \
    exec "${TARGET}" ${CMD}
