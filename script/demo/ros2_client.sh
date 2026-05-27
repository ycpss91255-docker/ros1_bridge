#!/usr/bin/env bash
#
# Demo A — ROS 2 client (subscriber).
#
# Subscribes to /chatter_1to2 from ROS 2. Run ros1_server.sh on the other
# terminal first — it owns roscore + parameter_bridge.

set -euo pipefail

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

    log "step 1/3: sourcing ROS 2 (${ROS2_DISTRO})"
    # `set +u` / `set -u` brackets isolate ROS's setup.bash chain
    # (catkin + ament profile.d dereference unbound vars) from our
    # strict-mode -- canonical pattern for sourcing third-party
    # setup scripts (refs #81).
    set +u
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS2_DISTRO}/setup.bash"
    set -u

    # Wait indefinitely for the paired ros1_server.sh to bring up
    # roscore + parameter_bridge so that ${TOPIC} appears on the ROS 2
    # side. ROS 2 has no central master, so without this wait the
    # client just sits silently in ros2 topic echo with zero output
    # whether the bridge is up or not -- indistinguishable hang.
    # Wait for the topic to actually exist; Ctrl+C to bail out.
    log "step 2/3: waiting for ${TOPIC} (paired ros1_server.sh + parameter_bridge)..."
    local _waited=0
    until ros2 topic list 2>/dev/null | grep -qx "${TOPIC}"; do
        _waited=$((_waited + 1))
        if [[ $((_waited % 25)) -eq 0 ]]; then
            log "        still waiting for ${TOPIC}... ($((_waited / 5))s)"
        fi
        sleep 0.2
    done
    log "        ${TOPIC} is up"

    log "step 3/3: subscribing to ${TOPIC} (Ctrl+C to stop)"
    ros2 topic echo "${TOPIC}" std_msgs/msg/String
}

main "$@"
