# TEST.md

**28 tests** total.

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

### Bridge config (5)

| Test | Description |
|------|-------------|
| `bridge.yaml exists` | `/bridge.yaml` exists |
| `entrypoint.sh exists and is executable` | `/entrypoint.sh` is executable |
| `ros_entrypoint.sh exists and is executable` | `/ros_entrypoint.sh` is executable |
| `ros_entrypoint.sh sources both ROS environments` | Running `/ros_entrypoint.sh` yields `ROS_DISTRO=foxy` (ROS 1 then ROS 2 sourced) |
| `ros_entrypoint.sh exposes ros2 command` | `ros2` binary is on `PATH` after entrypoint |

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
