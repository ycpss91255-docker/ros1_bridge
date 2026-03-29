# 測試文件

**24 個測試**。

## test/smoke/ros_env.bats

### ROS environment (4)

| 測試項目 | 說明 |
|----------|------|
| `ROS 1 (noetic) setup.bash exists` | `/opt/ros/noetic/setup.bash` exists |
| `ROS 2 (foxy) setup.bash exists` | `/opt/ros/foxy/setup.bash` exists |
| `ROS 1 environment can be sourced` | ROS 1 (noetic) setup script sources without error |
| `ROS 2 environment can be sourced after ROS 1` | ROS 2 (foxy) sources after ROS 1 without error |

### Bridge (1)

| 測試項目 | 說明 |
|----------|------|
| `ros1_bridge package is available` | `ros2 pkg list` includes ros1_bridge |

### Bridge config (3)

| 測試項目 | 說明 |
|----------|------|
| `bridge.yaml exists` | `/bridge.yaml` exists |
| `entrypoint.sh exists and is executable` | `/entrypoint.sh` is executable |
| `config directory exists` | `/config` directory exists |

## test/smoke/script_help.bats

### build.sh (3)

| 測試項目 | 說明 |
|----------|------|
| `build.sh -h exits 0` | Help exits successfully |
| `build.sh --help exits 0` | Help exits successfully |
| `build.sh -h prints usage` | Help output contains "Usage:" |

### run.sh (3)

| 測試項目 | 說明 |
|----------|------|
| `run.sh -h exits 0` | Help exits successfully |
| `run.sh --help exits 0` | Help exits successfully |
| `run.sh -h prints usage` | Help output contains "Usage:" |

### exec.sh (3)

| 測試項目 | 說明 |
|----------|------|
| `exec.sh -h exits 0` | Help exits successfully |
| `exec.sh --help exits 0` | Help exits successfully |
| `exec.sh -h prints usage` | Help output contains "Usage:" |

### stop.sh (3)

| 測試項目 | 說明 |
|----------|------|
| `stop.sh -h exits 0` | Help exits successfully |
| `stop.sh --help exits 0` | Help exits successfully |
| `stop.sh -h prints usage` | Help output contains "Usage:" |
