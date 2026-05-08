#!/usr/bin/env bash
# ROS setup.bash + catkin profile scripts reference unset vars, so -u is omitted.
set -e

# unset ROS_DISTRO to silence override warning before sourcing ROS 1
unset ROS_DISTRO
# shellcheck source=/dev/null
source "/opt/ros/${ROS1_DISTRO}/setup.bash" --

# unset ROS_DISTRO to silence override warning before sourcing ROS 2
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

exec "${@}"
