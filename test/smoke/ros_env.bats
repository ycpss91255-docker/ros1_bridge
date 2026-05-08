#!/usr/bin/env bats

setup() {
    load "${BATS_TEST_DIRNAME}/test_helper"
}

# -------------------- ROS environment --------------------

@test "ROS 1 (noetic) setup.bash exists" {
    assert [ -f "/opt/ros/noetic/setup.bash" ]
}

@test "ROS 2 (\${ROS2_DISTRO}) setup.bash exists" {
    assert [ -f "/opt/ros/${ROS2_DISTRO}/setup.bash" ]
}

@test "ROS 1 environment can be sourced" {
    run bash -c "source /opt/ros/${ROS1_DISTRO}/setup.bash && echo ok"
    assert_success
    assert_line "ok"
}

@test "ROS 2 environment can be sourced after ROS 1" {
    run bash -c "source /opt/ros/${ROS1_DISTRO}/setup.bash && source /opt/ros/${ROS2_DISTRO}/setup.bash && echo ok"
    assert_success
    assert_line "ok"
}

@test "ros1_bridge package is available" {
    # ros1_bridge is built from source into /bridge_ws (not into the ROS 2
    # distro tree), so its install overlay must be sourced too.
    run bash -c "source /opt/ros/${ROS1_DISTRO}/setup.bash && source /opt/ros/${ROS2_DISTRO}/setup.bash && source /bridge_ws/install/setup.bash && ros2 pkg list | grep ros1_bridge"
    assert_success
}

@test "ROS1_DISTRO env var is set to noetic" {
    assert_equal "${ROS1_DISTRO}" "noetic"
}

@test "ROS2_DISTRO env var is set (humble or jazzy)" {
    # Dockerfile selects between the two via ARG ROS2_DISTRO; the smoke
    # spec is distro-agnostic but rejects unset / unsupported values.
    case "${ROS2_DISTRO}" in
        humble|jazzy) ;;
        *) flunk "ROS2_DISTRO is '${ROS2_DISTRO}', expected 'humble' or 'jazzy'" ;;
    esac
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
    # ros_entrypoint.sh sources ROS 1 then ROS 2; final ROS_DISTRO matches ${ROS2_DISTRO}.
    run /ros_entrypoint.sh bash -c 'echo "${ROS_DISTRO}"'
    assert_success
    assert_line "${ROS2_DISTRO}"
}

@test "ros_entrypoint.sh exposes ros2 command" {
    run /ros_entrypoint.sh which ros2
    assert_success
}

@test "entrypoint.sh skips rosparam load when roscore unreachable" {
    # Regression for the `rosparam load` unconditional call that blocked
    # container boot on any host without a reachable roscore. With the
    # timeout guard, entrypoint.sh prints a warning to stderr and still
    # exec's the CMD so the container comes up.
    #
    # Force "unreachable": point ROS_MASTER_URI at a port with no roscore.
    # `timeout 2 rosparam list` blocks up to 2s before returning non-zero;
    # the test therefore takes ~2s real time (acceptable for a correctness
    # test guarded on an actual hang symptom upstream).
    run env ROS_MASTER_URI=http://127.0.0.1:11311 bash /entrypoint.sh echo hello
    assert_success
    assert_output --partial "roscore not reachable"
    assert_output --partial "hello"
}

# -------------------- Demo helpers --------------------

@test "demo_bridge.yaml exists" {
    assert [ -f "/demo_bridge.yaml" ]
}

@test "ros1_server.sh exists and is executable" {
    assert [ -x "/ros1_server.sh" ]
}

@test "ros1_client.sh exists and is executable" {
    assert [ -x "/ros1_client.sh" ]
}

@test "ros2_server.sh exists and is executable" {
    assert [ -x "/ros2_server.sh" ]
}

@test "ros2_client.sh exists and is executable" {
    assert [ -x "/ros2_client.sh" ]
}

@test "ros1_server.sh -h prints usage" {
    run bash /ros1_server.sh -h
    assert_success
    assert_line --partial "Usage:"
}

@test "ros1_client.sh -h prints usage" {
    run bash /ros1_client.sh -h
    assert_success
    assert_line --partial "Usage:"
}

@test "ros2_server.sh -h prints usage" {
    run bash /ros2_server.sh -h
    assert_success
    assert_line --partial "Usage:"
}

@test "ros2_client.sh -h prints usage" {
    run bash /ros2_client.sh -h
    assert_success
    assert_line --partial "Usage:"
}
