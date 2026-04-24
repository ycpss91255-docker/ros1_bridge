#!/usr/bin/env bash
#
# Demo A — ROS 2 client (subscriber).
#
# Subscribes to /chatter_1to2 from ROS 2. Run ros1_server.sh on the other
# terminal first — it owns roscore + parameter_bridge.

set -e

readonly TOPIC="/chatter_1to2"

usage() {
    cat >&2 <<EOF
Usage: ros2_client.sh [-h|--help]

Demo A (ROS 1 -> ROS 2) — client / subscriber side.

Subscribes to ${TOPIC} from ROS 2. Start ros1_server.sh on a second
terminal first — it owns roscore + parameter_bridge.
EOF
}

log() {
    printf '[ros2_client] %s\n' "$*"
}

main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
    esac

    log "step 1/2: sourcing ROS 2 (${ROS2_DISTRO})"
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS2_DISTRO}/setup.bash"

    log "step 2/2: subscribing to ${TOPIC} (Ctrl+C to stop)"
    ros2 topic echo "${TOPIC}" std_msgs/msg/String
}

main "$@"
