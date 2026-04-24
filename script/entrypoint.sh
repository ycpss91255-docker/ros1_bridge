#!/usr/bin/env bash
set -e

# source ROS1 + ROS2
source /opt/ros/noetic/setup.bash
source /opt/ros/foxy/setup.bash

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
