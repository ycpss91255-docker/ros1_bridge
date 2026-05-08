#!/usr/bin/env bash
set -e

# Source ROS 1 + ROS 2 + ros1_bridge install overlay. The trailing `--`
# is required: bash's `source` propagates the calling script's positional
# parameters to the sourced file by default, so without `--` the CMD
# args (e.g. `ros2 run ros1_bridge parameter_bridge --help`) get fed
# straight into catkin's `_setup_util.py "$@"`. argparse there sees
# `--help`, prints usage to stdout, the wrapper captures stdout to a
# temp file and tries to `source` it — bash then fails with
# `setup.sh.<random>: line 1: usage:: command not found`. Passing `--`
# resets the sourced script's positional args to a single `--` token
# which `_setup_util.py` treats as end-of-options.
# shellcheck source=/dev/null
source "/opt/ros/${ROS1_DISTRO}/setup.bash" --
# shellcheck source=/dev/null
source "/opt/ros/${ROS2_DISTRO}/setup.bash" --
# ros1_bridge install overlay (source build, not in /opt/ros/${ROS2_DISTRO})
if [[ -f /bridge_ws/install/setup.bash ]]; then
    # shellcheck source=/dev/null
    source /bridge_ws/install/setup.bash --
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
