#!/usr/bin/env bash
#
# Demo B — ROS 1 client (subscriber).
#
# Subscribes to /chatter_2to1 from ROS 1. Run ros2_server.sh on the other
# terminal first — it owns roscore + parameter_bridge.

set -euo pipefail

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

    log "step 1/3: sourcing ROS 1 (${ROS1_DISTRO})"
    # `set +u` / `set -u` brackets isolate ROS's setup.bash chain
    # (catkin + ament profile.d dereference unbound vars) from our
    # strict-mode -- canonical pattern for sourcing third-party
    # setup scripts (refs #81).
    set +u
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS1_DISTRO}/setup.bash"
    set -u

    # Wait indefinitely for the paired ros2_server.sh to bring up roscore
    # + parameter_bridge. Without this, opening the client terminal
    # first crashes immediately with ROSMasterException -- demo UX bug.
    # Ctrl+C to bail out. Heartbeat every ~5s so the wait doesn't look
    # like a hang.
    log "step 2/3: waiting for roscore at ${ROS_MASTER_URI:-http://localhost:11311}..."
    local _waited=0
    until rostopic list >/dev/null 2>&1; do
        _waited=$((_waited + 1))
        if [[ $((_waited % 25)) -eq 0 ]]; then
            log "        still waiting for roscore... ($((_waited / 5))s)"
        fi
        sleep 0.2
    done
    log "        roscore reachable"

    log "step 3/3: subscribing to ${TOPIC} (Ctrl+C to stop)"
    rostopic echo "${TOPIC}"
}

main "$@"
