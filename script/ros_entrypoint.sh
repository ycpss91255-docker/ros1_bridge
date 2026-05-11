#!/usr/bin/env bash
set -euo pipefail

# `set +u` / `set -u` brackets isolate ROS's setup.bash chain (catkin
# + ament profile.d entries dereference unbound vars like
# ROS_MASTER_URI / AMENT_TRACE_SETUP_FILES) from our strict-mode
# guarantees -- canonical pattern for sourcing third-party setup
# scripts (compare venv / conda / nvm). Closes #81.
#
# `unset ROS_DISTRO` inside the bracket silences catkin's distro-mix
# warning when re-sourcing for ROS 2 after ROS 1; safe because the
# unset only runs while -u is off.
set +u
unset ROS_DISTRO
# shellcheck source=/dev/null
source "/opt/ros/${ROS1_DISTRO}/setup.bash" --

unset ROS_DISTRO
# shellcheck source=/dev/null
source "/opt/ros/${ROS2_DISTRO}/setup.bash" --

# ros1_bridge is built from source into /bridge_ws (Dockerfile devel stage),
# not installed into the ROS 2 distro tree. Source its install overlay so
# `ros2 run ros1_bridge ...` and `ros2 pkg list | grep ros1_bridge` work.
if [[ -f /bridge_ws/install/setup.bash ]]; then
    # shellcheck source=/dev/null
    source /bridge_ws/install/setup.bash --
fi
set -u

exec "${@}"
