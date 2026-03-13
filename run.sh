#!/usr/bin/env bash

set -euo pipefail

FILE_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Parse arguments
DETACH=false
TARGET="runtime"

while [[ $# -gt 0 ]]; do
    case "$1" in
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
    docker compose -f "${FILE_PATH}/compose.yaml" up -d "${TARGET}"
else
    docker compose -f "${FILE_PATH}/compose.yaml" run --rm "${TARGET}" "$@"
fi
