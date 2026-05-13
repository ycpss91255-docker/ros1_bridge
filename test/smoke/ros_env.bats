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
        *) fail "ROS2_DISTRO is '${ROS2_DISTRO}', expected 'humble' or 'jazzy'" ;;
    esac
}

# -------------------- Bridge config --------------------

@test "bridge.yaml exists" {
    assert [ -f "/bridge.yaml" ]
}

@test "bridge.yaml is non-empty (fresh-clone fallback regression #65)" {
    # Pre-#65, the Dockerfile COPYed ${BRIDGE_FILE} (default `bridge.yaml`,
    # gitignored per-clone symlink) at build time. On a fresh clone with no
    # symlink and no `--build-arg BRIDGE_FILE` override the build failed at
    # the COPY step with `failed to compute cache key: "/bridge.yaml": not
    # found`. Post-fix, the Dockerfile uses `RUN --mount=type=bind` to fall
    # back to config/demo_bridge.yaml when the symlink is absent.
    #
    # If we got here at all, the build succeeded; this assertion catches
    # the corner case where the bind-mount cp produced an empty file.
    assert [ -s "/bridge.yaml" ]
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

@test "entrypoint.sh handles --help in CMD without source-propagation error" {
    # Regression for issue #59: bash's `source FILE` (without explicit
    # args) propagates the calling script's positional parameters to
    # the sourced file. /entrypoint.sh used to call
    # `source /opt/ros/${ROS1_DISTRO}/setup.bash` without trailing `--`,
    # so when CMD ended in `--help` (any --flag arg), catkin's
    # `_setup_util.py "$@"` saw `--help`, printed argparse usage to
    # stdout, and the setup wrapper sourced that usage as shell — the
    # container died with `setup.sh.<rand>: line 1: usage:: command
    # not found`. Fix: pass an explicit `--` to every `source ...`
    # call. This test verifies that a CMD ending in `--help` does NOT
    # surface the "usage::" symptom.
    run env ROS_MASTER_URI=http://127.0.0.1:11311 bash /entrypoint.sh echo --help
    assert_success
    refute_output --partial "usage::"
    assert_output --partial "--help"
}

# -------------------- Demo helpers --------------------

@test "demo_bridge.yaml exists" {
    assert [ -f "/demo_bridge.yaml" ]
}

@test "WORKDIR lands in /root/demo (closes #70)" {
    # Final Dockerfile WORKDIR for devel + runtime is /root/demo so that
    # users `./exec.sh` and land directly inside the demo folder. `ls`
    # at landing shows the 4 ros{1,2}_{server,client}.sh scripts without
    # the user knowing where they live. The smoke test stage inherits
    # this WORKDIR, so `pwd` here proves it.
    run pwd
    assert_success
    assert_line "/root/demo"
}

@test "ros1_server.sh exists and is executable" {
    assert [ -x "/root/demo/ros1_server.sh" ]
}

@test "ros1_client.sh exists and is executable" {
    assert [ -x "/root/demo/ros1_client.sh" ]
}

@test "ros2_server.sh exists and is executable" {
    assert [ -x "/root/demo/ros2_server.sh" ]
}

@test "ros2_client.sh exists and is executable" {
    assert [ -x "/root/demo/ros2_client.sh" ]
}

@test "ros1_server.sh -h prints usage" {
    run bash /root/demo/ros1_server.sh -h
    assert_success
    assert_line --partial "Usage:"
}

@test "ros1_client.sh -h prints usage" {
    run bash /root/demo/ros1_client.sh -h
    assert_success
    assert_line --partial "Usage:"
}

@test "ros2_server.sh -h prints usage" {
    run bash /root/demo/ros2_server.sh -h
    assert_success
    assert_line --partial "Usage:"
}

@test "ros2_client.sh -h prints usage" {
    run bash /root/demo/ros2_client.sh -h
    assert_success
    assert_line --partial "Usage:"
}

@test "ros1_server.sh step 4/4 publishes with sequence counter (--once loop)" {
    # Regression guard: step 4/4 must use `rostopic pub --once` inside a
    # bash while loop with an incrementing `seq` counter so each published
    # message is distinguishable. Reverting to `rostopic pub -r 1 ... data: 'fixed'`
    # would silently regress the demo to "every line identical".
    run grep -F 'rostopic pub --once' /root/demo/ros1_server.sh
    assert_success
    run grep -E 'seq=\$\(\(seq \+ 1\)\)' /root/demo/ros1_server.sh
    assert_success
    run grep -F '#${seq}' /root/demo/ros1_server.sh
    assert_success
}

@test "ros2_server.sh step 4/4 publishes with sequence counter (--once loop)" {
    # Same regression guard for the ROS 2 side (Demo B publisher).
    run grep -F 'ros2 topic pub --once' /root/demo/ros2_server.sh
    assert_success
    run grep -E 'seq=\$\(\(seq \+ 1\)\)' /root/demo/ros2_server.sh
    assert_success
    run grep -F '#${seq}' /root/demo/ros2_server.sh
    assert_success
}

# -------------------- colcon build parallelism (closes #79) --------------------

@test "colcon_build_bridge.sh: --print-jobs emits auto-detected -j<N> line" {
    # The script ran during builder stage with auto-detected -j; --print-jobs
    # re-runs the heuristic without invoking colcon so we can assert the
    # observable output format without re-building.
    run /tmp/colcon_build_bridge.sh --print-jobs
    assert_success
    assert_output --partial "[colcon] auto-detected -j"
}

@test "colcon_build_bridge.sh: BUILD_JOBS env override honored" {
    # Explicit override should bypass the heuristic and emit the exact value.
    run env BUILD_JOBS=1 /tmp/colcon_build_bridge.sh --print-jobs
    assert_success
    assert_output --partial "[colcon] auto-detected -j1"
}
