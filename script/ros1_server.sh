#!/usr/bin/env bash
#
# Demo A — ROS 1 server (publisher).
#
# Bootstraps roscore + parameter_bridge (using /demo_bridge.yaml), then
# publishes std_msgs/String "${MESSAGE}" on /chatter_1to2 at 1 Hz from ROS 1.
# Pair with ros2_client.sh on a second terminal.
#
# Each command runs in its own subshell so ROS 1 and ROS 2 envs never
# collide — sourcing both into one shell breaks roscore (Python imports
# ROS 2's rosgraph_msgs.Log instead of ROS 1's).

set -euo pipefail

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

# Source ROS 1 only (for roscore, rostopic, rosparam). `set +u` / `set -u`
# brackets isolate ROS's setup.bash chain (catkin + ament profile.d
# dereference unbound vars) from our strict-mode -- canonical pattern
# for sourcing third-party setup scripts (refs #81).
ros1_env() {
    set +u
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS1_DISTRO}/setup.bash" >/dev/null 2>&1
    set -u
}

# Source ROS 1 then ROS 2 (for parameter_bridge — needs both).
# ros1_bridge is built from source into /bridge_ws (not installed under
# /opt/ros/${ROS2_DISTRO}/share), so its overlay must be sourced too.
both_env() {
    ros1_env
    set +u
    unset ROS_DISTRO
    # shellcheck source=/dev/null
    source "/opt/ros/${ROS2_DISTRO}/setup.bash" >/dev/null 2>&1
    if [[ -f /bridge_ws/install/setup.bash ]]; then
        # shellcheck source=/dev/null
        source /bridge_ws/install/setup.bash >/dev/null 2>&1
    fi
    set -u
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
    until ( ros1_env; rostopic list ) 2>/dev/null | grep -qx "${TOPIC}"; do
        i=$((i + 1))
        if [[ "${i}" -gt 50 ]]; then
            log "        WARNING: ${TOPIC} not seen after 10s — continuing anyway."
            break
        fi
        sleep 0.2
    done
    log "        bridge ready (pid=${BRIDGE_PID})"

    log "step 4/4: publishing on ${TOPIC} with sequence counter — ROS 1 env"
    log "        Each iteration spawns rostopic pub --once, so effective rate"
    log "        is ~0.5-0.7 Hz (rospy init dominates). Ctrl+C to stop everything."
    # Log BEFORE the publish call, not after: rostopic pub --once takes
    # ~700ms to spin up rospy, register the publisher, and emit -- during
    # which the bridge has already relayed the message and the ROS 2
    # client has printed it. Logging after the subshell exits would make
    # the server's "#N" appear chronologically AFTER the client's #N,
    # which reads as desync even though everything is fine on the wire.
    local seq=0
    while true; do
        seq=$((seq + 1))
        log "        publishing #${seq}..."
        ( ros1_env; exec rostopic pub --once "${TOPIC}" std_msgs/String \
            "data: '${message} #${seq}'" ) >/dev/null 2>&1
        sleep 1
    done
}

main "$@"
