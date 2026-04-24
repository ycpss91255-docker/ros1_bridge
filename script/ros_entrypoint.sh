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

exec "${@}"
