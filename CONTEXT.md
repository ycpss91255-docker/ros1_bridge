# CONTEXT.md

Domain knowledge for the `ros1_bridge` container repo. CLAUDE.md
points here for domain context; ADRs live in `doc/adr/`.

## Bridge Config Resolution

Two independent paths determine which bridge YAML config is loaded
at runtime. They serve different use cases and intentionally read
different files:

| Path | Config file in container | Source | Used by |
|---|---|---|---|
| **Runtime (headless)** | `/bridge.yaml` | Operator-picked symlink baked at `docker build` time (falls back to `config/ros1_bridge/demo_bridge.yaml` when missing) | `make run -- -t runtime` via `entrypoint.sh` `rosparam load` |
| **Demo (interactive)** | `/demo_bridge.yaml` | Always `config/ros1_bridge/demo_bridge.yaml`, hardcoded in demo server scripts | `make exec -- /root/demo/ros1_server.sh` etc. |

**Why demos ignore the operator config:** demo scripts are
self-contained reproducibility tools. They bootstrap their own
`roscore` + `parameter_bridge` with a known-good config
(`/demo_bridge.yaml` = bidirectional `std_msgs/String` chatter) so
the demo works identically regardless of what the operator picked for
production bridging. To demo with a custom bridge config, use runtime
mode instead.

**Why bake at build time (not bind mount):** The runtime image is
designed as a self-contained deployment artifact (`docker pull` +
`docker run` on edge devices without a source checkout). YAML edits
cost a rebuild. See [ADR-00000001](doc/adr/00000001-runtime-image-immutable.md).

## ROS Environment Sourcing Order

Both entrypoints source ROS environments in the same order:

1. `/opt/ros/${ROS1_DISTRO}/setup.bash` (Noetic, source-built)
2. `/opt/ros/${ROS2_DISTRO}/setup.bash` (Humble or Jazzy, from base image)
3. `/bridge_ws/install/setup.bash` (ros1_bridge colcon overlay)

The `--` trailing argument after each `source` prevents the calling
script's positional parameters from leaking into catkin's
`_setup_util.py` argparse.

## Dockerfile Stage Graph

```
ros:${ROS2_DISTRO}-ros-base
  └→ builder        (source-build Noetic + ros1_bridge; keeps source trees)
       └→ devel     (+ demo scripts + ros_entrypoint.sh; CMD bash)
            └→ devel-test  (+ shellcheck + hadolint + bats; ephemeral)

ros:${ROS2_DISTRO}-ros-base
  └→ runtime        (COPY --from=builder install trees only; CMD parameter_bridge)
       └→ runtime-test  (ldd smoke gate; ephemeral)
```

`devel` inherits `builder` (source available for rebuild).
`runtime` restarts from the base image (lean, no build tools).
Both test stages are build-only and never pushed.
