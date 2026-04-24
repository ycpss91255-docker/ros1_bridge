#!/usr/bin/env bash
#
# Demo B — ROS 1 client (subscriber).
#
# Subscribes to /chatter_2to1 from ROS 1. Run ros2_server.sh on the other
# terminal first — it owns roscore + parameter_bridge.

set -e

readonly TOPIC="/chatter_2to1"

usage() {
    cat >&2 <<EOF
Usage: ros1_client.sh [-h|--help]

Demo B (ROS 2 -> ROS 1) — client / subscriber side.

Subscribes to ${TOPIC} from ROS 1. Start ros2_server.sh on a second
terminal first — it owns roscore + parameter_bridge.
EOF
}

log() {
    printf '[ros1_client] %s\n' "$*"
}

main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
    esac

    log "step 1/2: sourcing ROS 1 (${ROS1_DISTRO})"
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS1_DISTRO}/setup.bash"

    log "step 2/2: subscribing to ${TOPIC} (Ctrl+C to stop)"
    rostopic echo "${TOPIC}"
}

main "$@"
