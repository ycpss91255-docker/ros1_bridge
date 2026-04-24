#!/usr/bin/env bats

setup() {
    load "${BATS_TEST_DIRNAME}/test_helper"
}

# -------------------- ROS environment --------------------

@test "ROS 1 (noetic) setup.bash exists" {
    assert [ -f "/opt/ros/noetic/setup.bash" ]
}

@test "ROS 2 (foxy) setup.bash exists" {
    assert [ -f "/opt/ros/foxy/setup.bash" ]
}

@test "ROS 1 environment can be sourced" {
    run bash -c "source /opt/ros/noetic/setup.bash && echo ok"
    assert_success
    assert_line "ok"
}

@test "ROS 2 environment can be sourced after ROS 1" {
    run bash -c "source /opt/ros/noetic/setup.bash && source /opt/ros/foxy/setup.bash && echo ok"
    assert_success
    assert_line "ok"
}

@test "ros1_bridge package is available" {
    run bash -c "source /opt/ros/noetic/setup.bash && source /opt/ros/foxy/setup.bash && ros2 pkg list | grep ros1_bridge"
    assert_success
}

@test "ROS1_DISTRO env var is set to noetic" {
    assert_equal "${ROS1_DISTRO}" "noetic"
}

@test "ROS2_DISTRO env var is set to foxy" {
    assert_equal "${ROS2_DISTRO}" "foxy"
}

# -------------------- Bridge config --------------------

@test "bridge.yaml exists" {
    assert [ -f "/bridge.yaml" ]
}

@test "entrypoint.sh exists and is executable" {
    assert [ -x "/entrypoint.sh" ]
}

@test "ros_entrypoint.sh exists and is executable" {
    assert [ -x "/ros_entrypoint.sh" ]
}

@test "ros_entrypoint.sh sources both ROS environments" {
    run /ros_entrypoint.sh bash -c 'echo "${ROS_DISTRO}"'
    assert_success
    assert_line "foxy"
}

@test "ros_entrypoint.sh exposes ros2 command" {
    run /ros_entrypoint.sh which ros2
    assert_success
}
