#!/usr/bin/env bash

set -euo pipefail

FILE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

docker compose -f "${FILE_PATH}/compose.yaml" run --rm runtime "$@"
