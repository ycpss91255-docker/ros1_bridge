#!/usr/bin/env bash
#
# Demo B — ROS 2 server (publisher).
#
# Bootstraps roscore + parameter_bridge (using /demo_bridge.yaml), then
# publishes std_msgs/msg/String "${MESSAGE}" on /chatter_2to1 at 1 Hz from
# ROS 2. Pair with ros1_client.sh on a second terminal.
#
# Each command runs in its own subshell so ROS 1 and ROS 2 envs never
# collide — sourcing both into one shell breaks roscore (Python imports
# ROS 2's rosgraph_msgs.Log instead of ROS 1's).

set -e

readonly TOPIC="/chatter_2to1"
readonly BRIDGE_YAML="/demo_bridge.yaml"
readonly DEFAULT_MESSAGE="hello from ROS 2"

usage() {
    cat >&2 <<EOF
Usage: ros2_server.sh [-h|--help]

Demo B (ROS 2 -> ROS 1) — server / publisher side.

Bootstraps roscore + parameter_bridge from ${BRIDGE_YAML}, then publishes
std_msgs/msg/String on ${TOPIC} at 1 Hz from ROS 2.

Pair with ros1_client.sh on a second terminal.

Environment:
  MESSAGE   Override the published string (default: "${DEFAULT_MESSAGE}").
EOF
}

log() {
    printf '[ros2_server] %s\n' "$*"
}

# Source ROS 1 only (for roscore, rostopic, rosparam).
ros1_env() {
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS1_DISTRO}/setup.bash" >/dev/null 2>&1
}

# Source ROS 2 only (for ros2 CLI).
ros2_env() {
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS2_DISTRO}/setup.bash" >/dev/null 2>&1
}

# Source ROS 1 then ROS 2 (for parameter_bridge — needs both).
# ros1_bridge is built from source into /bridge_ws (not installed under
# /opt/ros/${ROS2_DISTRO}/share), so its overlay must be sourced too.
both_env() {
    ros1_env
    ros2_env
    if [[ -f /bridge_ws/install/setup.bash ]]; then
        # shellcheck source=/dev/null
        source /bridge_ws/install/setup.bash >/dev/null 2>&1
    fi
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

    log "step 1/4: starting roscore in background — ROS 1 only env (log: /tmp/roscore.log)"
    ( ros1_env; exec roscore ) >/tmp/roscore.log 2>&1 &
    ROSCORE_PID="${!}"
    trap cleanup EXIT INT TERM

    log "        waiting for rosmaster..."
    until ( ros1_env; rostopic list ) >/dev/null 2>&1; do sleep 0.2; done
    log "        rosmaster ready (pid=${ROSCORE_PID})"

    log "step 2/4: loading bridge config from ${BRIDGE_YAML} — ROS 1 env"
    ( ros1_env; exec rosparam load "${BRIDGE_YAML}" )

    log "step 3/4: starting parameter_bridge in background — ROS 1 + ROS 2 env (log: /tmp/bridge.log)"
    ( both_env; exec ros2 run ros1_bridge parameter_bridge ) >/tmp/bridge.log 2>&1 &
    BRIDGE_PID="${!}"

    log "        waiting for bridge to expose ${TOPIC} (timeout 10s)..."
    local i=0
    until ( ros2_env; ros2 topic list ) 2>/dev/null | grep -qx "${TOPIC}"; do
        i=$((i + 1))
        if [[ "${i}" -gt 50 ]]; then
            log "        WARNING: ${TOPIC} not seen after 10s — continuing anyway."
            break
        fi
        sleep 0.2
    done
    log "        bridge ready (pid=${BRIDGE_PID})"

    log "step 4/4: publishing on ${TOPIC} at 1 Hz: \"${message}\" — ROS 2 (${ROS2_DISTRO}) env"
    log "        Ctrl+C to stop everything."
    ( ros2_env; exec ros2 topic pub -r 1 "${TOPIC}" std_msgs/msg/String "{data: '${message}'}" )
}

main "$@"
