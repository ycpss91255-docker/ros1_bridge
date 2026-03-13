#!/usr/bin/env bash

set -euo pipefail

FILE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

TARGET="${1:-runtime}"
shift 2>/dev/null || true
CMD="${*:-bash}"

docker compose -f "${FILE_PATH}/compose.yaml" \
    exec "${TARGET}" ${CMD}
