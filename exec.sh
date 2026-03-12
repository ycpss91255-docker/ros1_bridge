#!/usr/bin/env bash

set -euo pipefail

CONTAINER="ros1_bridge"
CMD="${1:-bash}"

docker exec -it "${CONTAINER}" "${CMD}"
