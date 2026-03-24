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

# -------------------- Bridge config --------------------

@test "bridge.yaml exists" {
    assert [ -f "/bridge.yaml" ]
}

@test "entrypoint.sh exists and is executable" {
    assert [ -x "/entrypoint.sh" ]
}

@test "config directory exists" {
    assert [ -d "/config" ]
}
