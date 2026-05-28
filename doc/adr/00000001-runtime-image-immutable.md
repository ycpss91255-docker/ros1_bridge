# ADR-00000001: Runtime Image Immutable

- **Date:** 2026-05-28
- **Status:** Accepted

## Context

The runtime stage produces a lean image (`ros:${ROS2_DISTRO}-ros-base`
+ COPY install trees from builder + auto-start `parameter_bridge`)
intended for deployment outside the development workspace. Users may
pull the image to an edge device, a Jetson, or a CI runner that has
no source checkout.

`bridge.yaml` (selected by the operator from
`config/ros1_bridge/*.yaml`) is the runtime bridge config consumed by
`parameter_bridge`. Two ways exist to make it available inside the
container:

1. **Bake at build time** — Dockerfile `RUN --mount=type=bind` copies
   the file into the image during `docker build`.
2. **Bind mount at run time** — `compose.yaml` mounts the host's
   `bridge.yaml` into the container on `docker compose up`.

The bind-mount path was considered because it allows editing the YAML
without a rebuild, shortening iteration on bridge config tuning.

## Decision

The runtime stage **bakes `bridge.yaml` into the image at build time**.
Editing the YAML requires a `make build` rebuild. Bind mount is not
used for any runtime config file.

## Alternatives

- **Bind mount `./bridge.yaml:/bridge.yaml:ro` in `compose.yaml`.**
  Rejected. Breaks the deployment promise: image consumers on edge
  devices, Jetson, or CI runners would need a source checkout to
  provide the YAML, defeating the point of shipping a self-contained
  runtime artifact.
- **Default to bake, opt-in bind mount via a separate compose profile.**
  Rejected for now. Adds a second supported path with no clear caller.
  If a future use case demands hot-reload (e.g. CI test rotation
  across configs), reopen this decision.

## Consequences

- Runtime image is a complete deployment artifact. `docker pull` +
  `docker run` works on any host with Docker, no source checkout, no
  external file dependency.
- YAML edits cost a rebuild (~14 min including catkin source build,
  partially mitigated by buildx GHA cache).
- Multiple bridge configs for the same image require multiple image
  tags (or rebuild between tests). Acceptable: bridge configs are
  small enough that rebuild is the right pace of change.
- The `devel` stage (interactive iteration) is unaffected — operators
  using `make run` for development still get the baked YAML, but they
  can also iterate by editing files inside the container and
  restarting `parameter_bridge` manually.
- Demo scripts in `script/demo/` continue to use the hardcoded
  `/demo_bridge.yaml` (also baked) for self-contained reproducibility
  — see CONTEXT.md "Bridge Config Resolution".
