#!/usr/bin/env bash

set -euo pipefail

FILE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Build target: runtime (default), test
TARGET="${1:-runtime}"

docker compose -f "${FILE_PATH}/compose.yaml" build "${TARGET}"
