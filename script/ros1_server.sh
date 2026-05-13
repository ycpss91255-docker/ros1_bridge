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
readonly DEFAULT_RATE="10"
readonly DEMO_PUB_PY="/root/demo/demo_pub_ros1.py"

usage() {
    cat >&2 <<EOF
Usage: ros1_server.sh [-h|--help] [-r|--rate <Hz>]

Demo A (ROS 1 -> ROS 2) — server / publisher side.

Bootstraps roscore + parameter_bridge from ${BRIDGE_YAML}, then publishes
std_msgs/String on ${TOPIC} from ROS 1 via ${DEMO_PUB_PY}
(long-lived rospy.Publisher, single rospy init at startup).

Pair with ros2_client.sh on a second terminal.

Options:
  -r, --rate <Hz>   Publish rate in Hz (default: ${DEFAULT_RATE}).

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
    local message="${MESSAGE:-${DEFAULT_MESSAGE}}"
    local rate="${DEFAULT_RATE}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -r|--rate)
                rate="${2:?-r/--rate requires a value (e.g. 10)}"
                shift 2
                ;;
            *)
                printf 'ros1_server.sh: unknown argument: %s\n' "$1" >&2
                usage
                exit 1
                ;;
        esac
    done

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

    log "step 4/4: handing off to ${DEMO_PUB_PY} at ${rate} Hz — ROS 1 env"
    log "        Long-lived rospy.Publisher: no per-iteration rospy init,"
    log "        so the requested rate is the actual rate. Counter is in"
    log "        the Python process. Ctrl+C to stop everything."
    ( ros1_env; exec python3 "${DEMO_PUB_PY}" \
        --topic "${TOPIC}" \
        --message "${message}" \
        --rate "${rate}" )
}

main "$@"
