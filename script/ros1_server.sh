#!/usr/bin/env bash
#
# Demo A — ROS 1 server (publisher).
#
# Bootstraps roscore + parameter_bridge (using /demo_bridge.yaml), then
# publishes std_msgs/String "${MESSAGE}" on /chatter_1to2 at 1 Hz from ROS 1.
# Pair with ros2_client.sh on a second terminal.
#
# Owns roscore + parameter_bridge: Ctrl+C tears both down.

set -e

readonly TOPIC="/chatter_1to2"
readonly BRIDGE_YAML="/demo_bridge.yaml"
readonly DEFAULT_MESSAGE="hello from ROS 1"

usage() {
    cat >&2 <<EOF
Usage: ros1_server.sh [-h|--help]

Demo A (ROS 1 -> ROS 2) — server / publisher side.

Bootstraps roscore + parameter_bridge from ${BRIDGE_YAML}, then publishes
std_msgs/String on ${TOPIC} at 1 Hz from ROS 1.

Pair with ros2_client.sh on a second terminal.

Environment:
  MESSAGE   Override the published string (default: "${DEFAULT_MESSAGE}").
EOF
}

log() {
    printf '[ros1_server] %s\n' "$*"
}

cleanup() {
    log "shutting down (parameter_bridge + roscore)..."
    [[ -n "${BRIDGE_PID:-}" ]] && kill "${BRIDGE_PID}" 2>/dev/null || true
    [[ -n "${ROSCORE_PID:-}" ]] && kill "${ROSCORE_PID}" 2>/dev/null || true
    wait 2>/dev/null || true
    log "done."
}

main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
    esac

    local message="${MESSAGE:-${DEFAULT_MESSAGE}}"

    log "step 1/5: sourcing ROS 1 (${ROS1_DISTRO}) + ROS 2 (${ROS2_DISTRO})"
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS1_DISTRO}/setup.bash"
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS2_DISTRO}/setup.bash"

    log "step 2/5: starting roscore in background (log: /tmp/roscore.log)"
    roscore >/tmp/roscore.log 2>&1 &
    ROSCORE_PID="${!}"
    trap cleanup EXIT INT TERM

    log "        waiting for rosmaster..."
    until rostopic list >/dev/null 2>&1; do sleep 0.2; done
    log "        rosmaster ready (pid=${ROSCORE_PID})"

    log "step 3/5: loading bridge config from ${BRIDGE_YAML}"
    rosparam load "${BRIDGE_YAML}"

    log "step 4/5: starting parameter_bridge in background (log: /tmp/bridge.log)"
    ros2 run ros1_bridge parameter_bridge >/tmp/bridge.log 2>&1 &
    BRIDGE_PID="${!}"

    log "        waiting for bridge to expose ${TOPIC} (timeout 10s)..."
    local i=0
    until rostopic list 2>/dev/null | grep -qx "${TOPIC}"; do
        i=$((i + 1))
        if [[ "${i}" -gt 50 ]]; then
            log "        WARNING: ${TOPIC} not seen after 10s — continuing anyway."
            break
        fi
        sleep 0.2
    done
    log "        bridge ready (pid=${BRIDGE_PID})"

    log "step 5/5: publishing on ${TOPIC} at 1 Hz: \"${message}\""
    log "        Ctrl+C to stop everything."
    rostopic pub -r 1 "${TOPIC}" std_msgs/String "data: '${message}'"
}

main "$@"
