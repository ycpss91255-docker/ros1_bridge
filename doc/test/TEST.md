# TEST.md

**38 tests** total.

## test/smoke/ros_env.bats

### ROS environment (6)

| Test | Description |
|------|-------------|
| `ROS 1 (noetic) setup.bash exists` | `/opt/ros/noetic/setup.bash` exists |
| `ROS 2 (foxy) setup.bash exists` | `/opt/ros/foxy/setup.bash` exists |
| `ROS 1 environment can be sourced` | ROS 1 (noetic) setup script sources without error |
| `ROS 2 environment can be sourced after ROS 1` | ROS 2 (foxy) sources after ROS 1 without error |
| `ROS1_DISTRO env var is set to noetic` | Image bakes `ROS1_DISTRO=noetic` env var |
| `ROS2_DISTRO env var is set to foxy` | Image bakes `ROS2_DISTRO=foxy` env var |

### Bridge (1)

| Test | Description |
|------|-------------|
| `ros1_bridge package is available` | `ros2 pkg list` includes ros1_bridge |

### Bridge config (6)

| Test | Description |
|------|-------------|
| `bridge.yaml exists` | `/bridge.yaml` exists |
| `entrypoint.sh exists and is executable` | `/entrypoint.sh` is executable |
| `ros_entrypoint.sh exists and is executable` | `/ros_entrypoint.sh` is executable |
| `ros_entrypoint.sh sources both ROS environments` | Running `/ros_entrypoint.sh` yields `ROS_DISTRO=foxy` (ROS 1 then ROS 2 sourced) |
| `ros_entrypoint.sh exposes ros2 command` | `ros2` binary is on `PATH` after entrypoint |
| `entrypoint.sh skips rosparam load when roscore unreachable` | `timeout 2 rosparam list` guards the `rosparam load` so a missing roscore doesn't hang container boot |

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

## test/smoke/script_help.bats

### build.sh (3)

| Test | Description |
|------|-------------|
| `build.sh -h exits 0` | Help exits successfully |
| `build.sh --help exits 0` | Help exits successfully |
| `build.sh -h prints usage` | Help output contains "Usage:" |

### run.sh (3)

| Test | Description |
|------|-------------|
| `run.sh -h exits 0` | Help exits successfully |
| `run.sh --help exits 0` | Help exits successfully |
| `run.sh -h prints usage` | Help output contains "Usage:" |

### exec.sh (3)

| Test | Description |
|------|-------------|
| `exec.sh -h exits 0` | Help exits successfully |
| `exec.sh --help exits 0` | Help exits successfully |
| `exec.sh -h prints usage` | Help output contains "Usage:" |

### stop.sh (3)

| Test | Description |
|------|-------------|
| `stop.sh -h exits 0` | Help exits successfully |
| `stop.sh --help exits 0` | Help exits successfully |
| `stop.sh -h prints usage` | Help output contains "Usage:" |
