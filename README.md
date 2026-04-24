# ROS 1 Bridge Docker Environment

**[English](README.md)** | **[繁體中文](doc/README.zh-TW.md)** | **[简体中文](doc/README.zh-CN.md)** | **[日本語](doc/README.ja.md)**

> **TL;DR** — ROS 1/2 bridge container built from `ros:foxy-ros-base-focal` plus the ROS 1 snapshot apt repo. Bridges ROS 1 (Noetic) and ROS 2 (Foxy) topics via `parameter_bridge`. Multi-arch base supports Jetson (arm64).
>
> ```bash
> ./build.sh && ./run.sh
> ```

---

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Bridge Configuration](#bridge-configuration)
- [Demo](#demo)
- [Architecture](#architecture)
- [Directory Structure](#directory-structure)

---

## Features

- **Self-built bridge**: `ros:foxy-ros-base-focal` base plus ROS 1 snapshot apt repo — installs ROS 1 Noetic and ROS 2 Foxy side-by-side
- **Jetson (arm64) support**: multi-arch base image (unlike `osrf/ros:foxy-ros1-bridge`, which is amd64 only)
- **Parameter bridge**: configurable topic bridging via YAML
- **devel / runtime split**: `devel` stage is a plain shell (`CMD bash`) for debugging; `runtime` stage auto-starts `parameter_bridge` from `/bridge.yaml`
- **Dual entrypoints**: `/entrypoint.sh` (sources both ROS distros + `rosparam load /bridge.yaml`) and `/ros_entrypoint.sh` (ROS env only, matches osrf convention)
- **Smoke Test**: Bats tests verify both ROS environments and bridge availability
- **Docker Compose**: single `compose.yaml` for build and run
- **Example configs**: includes scan and camera bridge configurations

## Quick Start

```bash
# 1. Build
./build.sh

# 2. Run (requires ROS master running)
./run.sh

# 3. Enter running container
./exec.sh
```

## Usage

### Build

```bash
./build.sh                       # Build devel (default)
./build.sh test                  # Build with smoke tests

docker compose build devel     # Equivalent
```

### Run

Two modes, picked by stage target:

```bash
./run.sh                         # devel: interactive bash shell, bridge NOT running
./run.sh -d                      # devel detached, join via ./exec.sh
```

For `runtime` (auto-bridge) you currently need a direct `docker run` — the
auto-generated `compose.yaml` does not yet emit a `runtime` service
(tracked upstream in template):

```bash
docker build --target runtime -t ros1_bridge:runtime .
docker run --rm --network=host ros1_bridge:runtime
# entrypoint sources both ROS distros, rosparam loads /bridge.yaml,
# then exec's `ros2 run ros1_bridge parameter_bridge`.
# Requires roscore already running on the host network.
```

### Enter running container

```bash
./exec.sh
./exec.sh bash
```

## Bridge Configuration

The default bridge config is `bridge.yaml`. Additional configs are in `config/`:

| File | Description |
|------|-------------|
| `bridge.yaml` | Default config (LaserScan `/scan`) |
| `config/scan_bridge.yaml` | LaserScan bridge |
| `config/release_bridge.yaml` | Camera + depth topics bridge |

To use a different config, rebuild with:

```bash
docker compose build --build-arg BRIDGE_FILE=config/release_bridge.yaml devel
```

### YAML Format

Topic `type` uses the ROS 2 form `<package>/msg/<MsgName>`; service `type`
uses the ROS 1 form `<package>/<SrvName>` (this asymmetry is intentional in
`parameter_bridge`). Per-topic QoS is supported via the `qos` key; see
[`bridge.yaml`](bridge.yaml) for the full set of tunables.

```yaml
topics:
  - topic: /scan
    type: sensor_msgs/msg/LaserScan
    queue_size: 10
    qos:
      history: keep_last
      depth: 5
      reliability: best_effort
      durability: volatile

services_1_to_2:
  - service: /add_two_ints
    type: example_interfaces/AddTwoInts

services_2_to_1:
  - service: /get_parameters
    type: rcl_interfaces/GetParameters
```

## Demo

Two-terminal end-to-end bridge demo using `std_msgs/String`. Both demos
use the same pattern: a **server** terminal that owns `roscore` +
`parameter_bridge` (loaded from the baked-in `/demo_bridge.yaml`), and a
**client** terminal that just subscribes.

| Demo | Terminal 1 (server) | Terminal 2 (client) |
|------|---------------------|---------------------|
| A — ROS 1 → ROS 2 | `./exec.sh /ros1_server.sh` | `./exec.sh /ros2_client.sh` |
| B — ROS 2 → ROS 1 | `./exec.sh /ros2_server.sh` | `./exec.sh /ros1_client.sh` |

Steps (assuming the container is up via `./run.sh -d`):

```bash
# Terminal 1 (server) — pick one demo
./exec.sh /ros1_server.sh    # Demo A
./exec.sh /ros2_server.sh    # Demo B

# Terminal 2 (client) — matching pair
./exec.sh /ros2_client.sh    # Demo A
./exec.sh /ros1_client.sh    # Demo B
```

Server scripts log every step (`[ros1_server] step N/5: ...`) so it's
clear when `roscore` and `parameter_bridge` are up. Override the
published string with `MESSAGE`:

```bash
./exec.sh env MESSAGE="hi from ROS 1" /ros1_server.sh
```

`Ctrl+C` on the server terminal tears down `parameter_bridge` and
`roscore`; the client terminal then EOFs.

## Architecture

```mermaid
graph TD
    EXT1["bats/bats:latest"]
    EXT2["alpine:latest"]
    EXT3["ros:foxy-ros-base-focal"]
    EXT4["snapshots.ros.org\n(noetic + foxy apt)"]

    EXT1 --> bats-src["bats-src"]
    EXT2 --> bats-ext["bats-extensions"]

    EXT3 --> devel["devel\nros1 + ros2 + entrypoints\nCMD bash"]
    EXT4 --> devel

    devel --> runtime["runtime\nCMD ros2 run ros1_bridge parameter_bridge"]

    bats-src --> test["test (ephemeral)\nsmoke tests, discarded after build"]
    bats-ext --> test
    devel --> test

```

## Smoke Tests

See [TEST.md](doc/test/TEST.md) for details.

## Directory Structure

```text
ros1_bridge/
├── compose.yaml                 # Docker Compose definition
├── Dockerfile                   # Multi-stage build (devel + runtime + test)
├── build.sh -> template/build.sh    # Symlink
├── run.sh -> template/run.sh        # Symlink
├── exec.sh -> template/exec.sh      # Symlink
├── stop.sh -> template/stop.sh      # Symlink
├── Makefile -> template/Makefile    # Symlink
├── .template_version            # Template subtree version (v0.4.1)
├── template/                    # Shared scripts, tests, CI (git subtree)
├── script/
│   ├── entrypoint.sh            # Sources ROS 1 + ROS 2, loads bridge config
│   ├── ros_entrypoint.sh        # ROS env only (osrf-compatible)
│   ├── ros1_server.sh           # Demo A publisher (bootstraps roscore + bridge)
│   ├── ros1_client.sh           # Demo B subscriber
│   ├── ros2_server.sh           # Demo B publisher (bootstraps roscore + bridge)
│   └── ros2_client.sh           # Demo A subscriber
├── bridge.yaml                  # Default bridge configuration
├── config/                      # Additional bridge configs
│   ├── scan_bridge.yaml         # LaserScan bridge
│   ├── release_bridge.yaml      # Camera + depth bridge
│   └── demo_bridge.yaml         # Demo bidirectional std_msgs/String
├── doc/                         # Translated READMEs
│   ├── README.zh-TW.md          # Traditional Chinese
│   ├── README.zh-CN.md          # Simplified Chinese
│   └── README.ja.md             # Japanese
├── .github/workflows/
│   └── main.yaml                # CI/CD (calls template reusable workflows)
└── test/smoke/                  # Bats environment tests (repo-specific)
    └── ros_env.bats
```
