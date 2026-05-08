# TEST.md

**49 tests** total (24 in `ros_env.bats` + 25 in `script_help.bats`).

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
| `bridge.yaml is non-empty (fresh-clone fallback regression #65)` | `/bridge.yaml` is non-empty; covers the Dockerfile-internal fallback to `config/demo_bridge.yaml` when no `bridge.yaml` symlink exists in build context (closes [#65](https://github.com/ycpss91255-docker/ros1_bridge/issues/65)) |
| `entrypoint.sh exists and is executable` | `/entrypoint.sh` is executable |
| `ros_entrypoint.sh exists and is executable` | `/ros_entrypoint.sh` is executable |
| `ros_entrypoint.sh sources both ROS environments` | Running `/ros_entrypoint.sh` yields `ROS_DISTRO=${ROS2_DISTRO}` (ROS 1 sourced first, then ROS 2 + `/bridge_ws/install`) |
| `ros_entrypoint.sh exposes ros2 command` | `ros2` binary is on `PATH` after entrypoint |
| `entrypoint.sh skips rosparam load when roscore unreachable` | `timeout 2 rosparam list` guards the `rosparam load` so a missing roscore doesn't hang container boot |
| `entrypoint.sh handles --help in CMD without source-propagation error` | Regression for #59: `source FILE --` prevents catkin's `_setup_util.py "$@"` from seeing CMD's `--help` and emitting argparse usage that breaks the temp-file source step |

### Demo helpers (9)

| Test | Description |
|------|-------------|
| `demo_bridge.yaml exists` | `/demo_bridge.yaml` exists (built into image from `config/demo_bridge.yaml`) |
| `ros1_server.sh exists and is executable` | `/ros1_server.sh` is executable |
| `ros1_client.sh exists and is executable` | `/ros1_client.sh` is executable |
| `ros2_server.sh exists and is executable` | `/ros2_server.sh` is executable |
| `ros2_client.sh exists and is executable` | `/ros2_client.sh` is executable |
| `ros1_server.sh -h prints usage` | Help exits 0 with "Usage:" |
| `ros1_client.sh -h prints usage` | Help exits 0 with "Usage:" |
| `ros2_server.sh -h prints usage` | Help exits 0 with "Usage:" |
| `ros2_client.sh -h prints usage` | Help exits 0 with "Usage:" |

## template/test/smoke/script_help.bats (25)

Inherited from the template; covers the 4 wrapper scripts (`build.sh` / `run.sh` / `exec.sh` / `stop.sh`) at three levels: help-flag plumbing (12), `LANG`/`SETUP_LANG` detection (4), and `--lang` translated usage output (9).

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
