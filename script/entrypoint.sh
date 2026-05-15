#!/usr/bin/env bash
set -euo pipefail

# Tee container stdout/stderr to /var/log/ros1_bridge/<service>.log when
# setup.conf [logging] local_path is set (base v0.30.0+). Two guards:
#   - ${USER:-root} default: build-time smoke (Dockerfile test stage) has
#     no login env so $USER is unset, and set -u would otherwise crash.
#   - File existence check: base ships the helper in .base/script/docker/
#     which only mounts at compose-runtime via the workspace volume,
#     not present during the test stage. No-op when missing.
if [[ -f "/home/${USER:-root}/work/.base/script/docker/_entrypoint_logging.sh" ]]; then
  # shellcheck source=/dev/null
  . "/home/${USER:-root}/work/.base/script/docker/_entrypoint_logging.sh"
fi

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
#
# `set +u` / `set -u` brackets isolate ROS's setup.bash chain (catkin
# + ament profile.d entries dereference unbound vars like
# ROS_MASTER_URI / AMENT_TRACE_SETUP_FILES) from our strict-mode
# guarantees -- canonical pattern for sourcing third-party setup
# scripts (compare venv / conda / nvm). Closes #81.
set +u
# shellcheck source=/dev/null
source "/opt/ros/${ROS1_DISTRO}/setup.bash" --
# shellcheck source=/dev/null
source "/opt/ros/${ROS2_DISTRO}/setup.bash" --
# ros1_bridge install overlay (source build, not in /opt/ros/${ROS2_DISTRO})
if [[ -f /bridge_ws/install/setup.bash ]]; then
    # shellcheck source=/dev/null
    source /bridge_ws/install/setup.bash --
fi
set -u

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
