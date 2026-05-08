#!/usr/bin/env bash
set -e

# source ROS1 + ROS2 (distro-agnostic — driven by env vars baked in Dockerfile)
# shellcheck source=/dev/null
source "/opt/ros/${ROS1_DISTRO}/setup.bash"
# shellcheck source=/dev/null
source "/opt/ros/${ROS2_DISTRO}/setup.bash"
# ros1_bridge install overlay (source build, not in /opt/ros/${ROS2_DISTRO})
if [[ -f /bridge_ws/install/setup.bash ]]; then
    # shellcheck source=/dev/null
    source /bridge_ws/install/setup.bash
fi

_bridge_file="/bridge.yaml"
if [ -s "${_bridge_file}" ]; then
    if timeout 2 rosparam list >/dev/null 2>&1; then
        printf "Loading ROS2 bridge parameters from %s\n" "${_bridge_file}"
        rosparam load "${_bridge_file}"
    else
        printf "roscore not reachable at %s, skipping rosparam load from %s\n" \
            "${ROS_MASTER_URI:-http://localhost:11311}" "${_bridge_file}" >&2
    fi
fi

exec "${@}"
