# TEST.md

**64 tests** total (37 in `ros_env.bats` + 27 in `script_help.bats`).

## test/smoke/ros_env.bats

### ROS environment (6)

| Test | Description |
|------|-------------|
| `ROS 1 (noetic) setup.bash exists` | `/opt/ros/noetic/setup.bash` exists (source-built into the image) |
| `ROS 2 (${ROS2_DISTRO}) setup.bash exists` | `/opt/ros/${ROS2_DISTRO}/setup.bash` exists (humble or jazzy, selected via `ARG ROS2_DISTRO`) |
| `ROS 1 environment can be sourced` | ROS 1 (noetic) setup script sources without error |
| `ROS 2 environment can be sourced after ROS 1` | ROS 2 (${ROS2_DISTRO}) sources after ROS 1 without error |
| `ROS1_DISTRO env var is set to noetic` | Image bakes `ROS1_DISTRO=noetic` env var |
| `ROS2_DISTRO env var is set (humble or jazzy)` | Image bakes `ROS2_DISTRO=humble` or `ROS2_DISTRO=jazzy`; rejects unset / unsupported values |

### Bridge (1)

| Test | Description |
|------|-------------|
| `ros1_bridge package is available` | `ros2 pkg list` includes ros1_bridge after sourcing `/bridge_ws/install/setup.bash` (source-built; not in `/opt/ros/${ROS2_DISTRO}/share`) |

### Bridge config (8)

| Test | Description |
|------|-------------|
| `bridge.yaml exists` | `/bridge.yaml` exists |
| `bridge.yaml is non-empty (fresh-clone fallback regression #65)` | `/bridge.yaml` is non-empty; covers the Dockerfile-internal fallback to `config/ros1_bridge/demo_bridge.yaml` when no `bridge.yaml` symlink exists in build context (closes [#65](https://github.com/ycpss91255-docker/ros1_bridge/issues/65)) |
| `entrypoint.sh exists and is executable` | `/entrypoint.sh` is executable |
| `ros_entrypoint.sh exists and is executable` | `/ros_entrypoint.sh` is executable |
| `ros_entrypoint.sh sources both ROS environments` | Running `/ros_entrypoint.sh` yields `ROS_DISTRO=${ROS2_DISTRO}` (ROS 1 sourced first, then ROS 2 + `/bridge_ws/install`) |
| `ros_entrypoint.sh exposes ros2 command` | `ros2` binary is on `PATH` after entrypoint |
| `entrypoint.sh skips rosparam load when roscore unreachable` | `timeout 2 rosparam list` guards the `rosparam load` so a missing roscore doesn't hang container boot |
| `entrypoint.sh handles --help in CMD without source-propagation error` | Regression for #59: `source FILE --` prevents catkin's `_setup_util.py "$@"` from seeing CMD's `--help` and emitting argparse usage that breaks the temp-file source step |

### Demo helpers (20)

| Test | Description |
|------|-------------|
| `demo_bridge.yaml exists` | `/demo_bridge.yaml` exists (built into image from `config/ros1_bridge/demo_bridge.yaml`) |
| `WORKDIR lands in /root/demo (closes #70)` | Final Dockerfile `WORKDIR` for devel + runtime is `/root/demo` so `./exec.sh` lands inside the demo folder; `pwd` regression guard |
| `ros1_server.sh exists and is executable` | `/root/demo/ros1_server.sh` is executable |
| `ros1_client.sh exists and is executable` | `/root/demo/ros1_client.sh` is executable |
| `ros2_server.sh exists and is executable` | `/root/demo/ros2_server.sh` is executable |
| `ros2_client.sh exists and is executable` | `/root/demo/ros2_client.sh` is executable |
| `ros1_server.sh -h prints usage` | Help exits 0 with "Usage:" |
| `ros1_client.sh -h prints usage` | Help exits 0 with "Usage:" |
| `ros2_server.sh -h prints usage` | Help exits 0 with "Usage:" |
| `ros2_client.sh -h prints usage` | Help exits 0 with "Usage:" |
| `demo_pub_ros1.py exists and is executable` | `/root/demo/demo_pub_ros1.py` is executable; long-lived rospy.Publisher backing ros1_server.sh step 4/4 |
| `demo_pub_ros2.py exists and is executable` | `/root/demo/demo_pub_ros2.py` is executable; long-lived rclpy node backing ros2_server.sh step 4/4 |
| `demo_pub_ros1.py --help prints usage with --rate flag` | argparse --help works after sourcing `/opt/ros/${ROS1_DISTRO}/setup.bash`; output mentions `--rate`, `--topic`, `--message` |
| `demo_pub_ros2.py --help prints usage with --rate flag` | argparse --help works after sourcing `/opt/ros/${ROS2_DISTRO}/setup.bash`; output mentions `--rate`, `--topic`, `--message` |
| `ros1_server.sh step 4/4 hands off to demo_pub_ros1.py (long-lived rospy)` | Regression guard: step 4/4 must `exec python3 ${DEMO_PUB_PY}` (single rospy init at startup), NOT the previous bash + `rostopic pub --once` loop. The loop pattern capped achievable rate at ~0.6 Hz; the Python publisher lifts that to the requested `--rate` |
| `ros2_server.sh step 4/4 hands off to demo_pub_ros2.py (long-lived rclpy)` | Same guard for the ROS 2 side (Demo B publisher) |
| `ros1_server.sh accepts -r/--rate flag (forwards to python publisher)` | bash arg parser handles BOTH `-r <Hz>` and `--rate <Hz>` (`-r\|--rate)` case-arm) and forwards via `--rate "${rate}"` to `demo_pub_ros1.py`. The short alias mirrors `run.sh -t/--target` convention |
| `ros2_server.sh accepts -r/--rate flag (forwards to python publisher)` | Same for the ROS 2 side |
| `ros1_client.sh waits for roscore before subscribing` | Regression guard: client must poll `rostopic list >/dev/null 2>&1` until roscore is reachable, then subscribe. Without this, opening the client before its paired ros2_server.sh used to ROSMasterException-and-exit immediately |
| `ros2_client.sh waits for the bridged topic before subscribing` | Same UX-symmetry guard for the ROS 2 side. Polls `ros2 topic list \| grep -qx ${TOPIC}` until the bridge republishes the topic, then subscribes. Without this, `ros2 topic echo` sits silently with zero output -- indistinguishable from "subscribed, no publisher" |

### colcon build parallelism (2)

| Test | Description |
|------|-------------|
| `colcon_build_bridge.sh: --print-jobs emits auto-detected -j<N> line` | `/tmp/colcon_build_bridge.sh --print-jobs` re-runs the `min(nproc, mem_gb/2)` heuristic without invoking colcon and prints `[colcon] auto-detected -j<N> (cpu=…, mem=…GB)`. Regression guard for the auto-detect path (closes [#79](https://github.com/ycpss91255-docker/ros1_bridge/issues/79)) |
| `colcon_build_bridge.sh: BUILD_JOBS env override honored` | `BUILD_JOBS=1` env override bypasses the heuristic and emits `-j1` verbatim |

## template/test/smoke/script_help.bats (27)

Inherited from the template; covers the 4 wrapper scripts (`build.sh` / `run.sh` / `exec.sh` / `stop.sh`) at four levels: help-flag plumbing (12), auto-apply default description (#365, 2), `LANG`/`SETUP_LANG` detection (4), and `--lang` translated usage output (9).

### Wrapper help flags (12)

| Test | Description |
|------|-------------|
| `build.sh -h exits 0` | Help exits successfully |
| `build.sh --help exits 0` | Help exits successfully |
| `build.sh -h prints usage` | Help output contains "Usage:" |
| `run.sh -h exits 0` | Help exits successfully |
| `run.sh --help exits 0` | Help exits successfully |
| `run.sh -h prints usage` | Help output contains "Usage:" |
| `exec.sh -h exits 0` | Help exits successfully |
| `exec.sh --help exits 0` | Help exits successfully |
| `exec.sh -h prints usage` | Help output contains "Usage:" |
| `stop.sh -h exits 0` | Help exits successfully |
| `stop.sh --help exits 0` | Help exits successfully |
| `stop.sh -h prints usage` | Help output contains "Usage:" |

### Language detection (4)

| Test | Description |
|------|-------------|
| `build.sh detects zh from LANG=zh_TW.UTF-8` | LANG locale → zh-TW usage |
| `build.sh detects ja from LANG=ja_JP.UTF-8` | LANG locale → ja usage |
| `build.sh defaults to en for LANG=en_US.UTF-8` | LANG locale → en usage |
| `build.sh SETUP_LANG overrides LANG` | `SETUP_LANG` env var beats `LANG` |

### `--lang` flag translated usage (9, template #222)

| Test | Description |
|------|-------------|
| `build.sh --help --lang zh-TW prints zh-TW usage` | `--lang` flag → zh-TW usage |
| `build.sh --help --lang zh-CN prints zh-CN usage` | `--lang` flag → zh-CN usage |
| `build.sh --help --lang ja prints ja usage` | `--lang` flag → ja usage |
| `run.sh --help --lang zh-TW prints zh-TW usage` | `--lang` flag → zh-TW usage |
| `run.sh --help --lang ja prints ja usage` | `--lang` flag → ja usage |
| `exec.sh --help --lang zh-TW prints zh-TW usage` | `--lang` flag → zh-TW usage |
| `exec.sh --help --lang ja prints ja usage` | `--lang` flag → ja usage |
| `stop.sh --help --lang zh-TW prints zh-TW usage` | `--lang` flag → zh-TW usage |
| `stop.sh --help --lang ja prints ja usage` | `--lang` flag → ja usage |
