#!/usr/bin/env bash
set -e

# source ROS1 + ROS2
source /opt/ros/noetic/setup.bash
source /opt/ros/foxy/setup.bash

_bridge_file="/bridge.yaml"
if [ -s "${_bridge_file}" ]; then
    printf "Loading ROS2 bridge parameters from %s\n" "${_bridge_file}"
    rosparam load "${_bridge_file}"
fi

exec "${@}"
