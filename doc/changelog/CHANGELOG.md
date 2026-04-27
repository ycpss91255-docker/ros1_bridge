**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Upgrade `template/` subtree to [v0.11.0-rc1](https://github.com/ycpss91255-docker/template/releases/tag/v0.11.0-rc1). Closes Phase B of template #49 — `setup.sh` is now a git-style backend with `apply` / `check-drift` / `set` / `show` / `list` / `add` / `remove` / `reset` subcommands. Downstream-relevant points:
  - **BREAKING upstream**: `setup.sh` no-arg / flag-only invocation no longer aliases to `apply`. `build.sh` / `run.sh` / `setup_tui.sh` / `init.sh` were all updated in this template release to pass `apply` explicitly. ros1_bridge has no custom `setup.sh` callers, so no repo-side migration needed.
  - `main.yaml` pins workflows to `@v0.11.0-rc1` and passes `test_tools_version: v0.11.0-rc1` (GHCR multi-arch test-tools image is published).
- Upgrade `template/` subtree to [v0.10.2](https://github.com/ycpss91255-docker/template/releases/tag/v0.10.2). Two-hotfix stack on top of v0.10.0:
  - **v0.10.1**: `build-worker.yaml` replaces the broken `GITHUB_WORKFLOW_REF` test-tools auto-parse (which read the caller's own tag on downstream release pushes — `ros1_bridge v1.5.0` hit this and 404'd on `ghcr.io/.../test-tools:v1.5.0`) with an explicit `test_tools_version` input.
  - **v0.10.2**: `release-worker.yaml` drops `compose.yaml` from the release archive `cp -r` list (gitignored derived artifact since v0.9.0; kept in the cp list this whole time). The failed `cp` also killed `action-gh-release`, so tag pushes never produced a GitHub Release.

## [v1.5.0] - 2026-04-24

First minor release after v1.4.x. Substantial upgrade: Jetson / arm64 native support end-to-end (devel rebuilt from multi-arch base, arm64 CI matrix, GHCR test-tools with correct aarch64 binaries), template bump to v0.10.0 (runtime compose service, run.sh arg realignment, GHCR test-tools D plan, --reset-conf), new 2-terminal demo scripts, and robustness fixes (entrypoint timeout guard, Dockerfile stage migration to test-tools:local).

**BREAKING** for users who were invoking `./run.sh runtime` as a positional target: rewrite as `./run.sh -t runtime`. `./run.sh` bare call is unchanged (devel bash).

### Changed
- Upgrade `template/` subtree to [v0.10.0](https://github.com/ycpss91255-docker/template/releases/tag/v0.10.0). Bundles:
  - **Compose `runtime` service** auto-emitted by `setup.sh` when Dockerfile declares `FROM … AS runtime` (closes template #108). `./run.sh -t runtime` no longer errors with "no such service".
  - **`run.sh` arg realignment** (closes template #118, BREAKING): target is now `-t/--target` flag (default `devel`); positional args become CMD passthrough (empty → Dockerfile CMD, non-empty → override); `-d + cmd` → exit 2 error. `./run.sh` bare unchanged (devel bash). Migration inside this repo: `./run.sh runtime` now written as `./run.sh -t runtime` (auto-runs `parameter_bridge` attached). `./run.sh -t runtime bash` drops into runtime shell for debug.
  - **arm64 test-tools** hotfix — `Dockerfile.test-tools` `ARG TARGETARCH=amd64` default used to shadow BuildKit's auto-inject (moby/buildkit#3403), so `:v0.9.13` / `:v0.10.0-rc1` GHCR arm64 variants shipped x86_64 shellcheck / hadolint. v0.10.0-rc2+ drops the default; arm64 binaries are now genuinely aarch64 (verified via `docker cp` + `file`).
  - **`--reset-conf` flag on `build.sh`** (closes template #124) — restores `setup.conf` to the template default in one step, backing up the existing `setup.conf` → `setup.conf.bak` and `.env` → `.env.bak` first. `-y` / `--yes` skips the confirmation prompt.
  - **`upgrade.sh` sed regex fix** (closes template #61) — handles semver pre-release tags so future RC upgrades stop producing `-rcN-rcM` double suffixes.
  - Intermediate releases (v0.9.11 through v0.10.0-rc2) are superseded; this PR pins `main.yaml` directly to `@v0.10.0`.
- Pin `main.yaml` reusable workflows to [`@v0.10.0`](https://github.com/ycpss91255-docker/template/releases/tag/v0.10.0).
- Rebuild `devel` stage from `ros:foxy-ros-base-focal` (multi-arch) plus the ROS 1 snapshot apt repo instead of the amd64-only `osrf/ros:foxy-ros1-bridge`. Enables Jetson (arm64) support.
- `ENV ROS1_DISTRO=noetic` / `ENV ROS2_DISTRO=foxy` now baked into the image so downstream scripts can reference the distro names without hardcoding.
- Test stage lint target uses `COPY script/*.sh /lint/` (glob) to pick up new scripts automatically.
- Dockerfile `COPY` for `script/` switched from per-file (`entrypoint.sh`, `ros_entrypoint.sh`) to directory glob (`COPY --chmod=0755 script/ /`) so new helpers (the four demo scripts) are picked up without further Dockerfile edits.
- Bridge YAML examples now document the full `parameter_bridge` schema: `bridge.yaml` ships `services_1_to_2` / `services_2_to_1` entries and an inline QoS block on `/scan`; `config/scan_bridge.yaml` and `config/release_bridge.yaml` set sensor-data QoS (BEST_EFFORT for image streams, RELIABLE for `camera_info`). READMEs in all four languages note the topic (ROS 2) vs service (ROS 1) `type` format asymmetry.
- **Split `devel` and `runtime` into separate stages (USER-VISIBLE BEHAVIOR CHANGE).** `devel` CMD is now `bash` — `./run.sh` drops into an interactive shell instead of auto-launching `parameter_bridge`. `devel` ENTRYPOINT is `/ros_entrypoint.sh` (sources ROS1+ROS2 env only, no `rosparam load`) so the shell is usable immediately. The new `runtime` stage (`FROM devel`) keeps `CMD ["ros2", "run", "ros1_bridge", "parameter_bridge"]` and switches ENTRYPOINT back to `/entrypoint.sh` (which does `rosparam load /bridge.yaml` before launch) for production-style auto-bridge deployments. CI builds both (`build_runtime: true` in `main.yaml`). Note: `./run.sh runtime` does not yet work because the auto-generated `compose.yaml` does not emit a `runtime` service (tracked upstream in template); invoke runtime via direct `docker build --target runtime && docker run` until template provides this.

### Added
- `script/ros_entrypoint.sh` — osrf-compatible entrypoint that only sources both ROS distros (no `rosparam load`), available at `/ros_entrypoint.sh` in the image. `devel` stage uses this as its `ENTRYPOINT`; `runtime` stage keeps `/entrypoint.sh` (with `rosparam load`).
- **Demo scripts** — symmetric server/client pairs that run a 2-terminal end-to-end bridge demo with std_msgs/String. Each `*_server.sh` self-bootstraps `roscore` + `parameter_bridge` (loading `/demo_bridge.yaml`) before publishing, with explicit step-by-step logs (`[ros1_server] step N/5: ...`); each `*_client.sh` only sources the relevant distro and subscribes. Trap on the server tears down `roscore` + bridge on Ctrl+C.
  - `script/ros1_server.sh` — Demo A publisher: bootstraps + `rostopic pub /chatter_1to2 std_msgs/String`. Pair with `ros2_client.sh`.
  - `script/ros2_client.sh` — Demo A subscriber: `ros2 topic echo /chatter_1to2`.
  - `script/ros2_server.sh` — Demo B publisher: bootstraps + `ros2 topic pub /chatter_2to1 std_msgs/msg/String`. Pair with `ros1_client.sh`.
  - `script/ros1_client.sh` — Demo B subscriber: `rostopic echo /chatter_2to1`.
  - `MESSAGE` env var overrides the published string on either server.
- `config/demo_bridge.yaml` — bidirectional `std_msgs/msg/String` bridge for `/chatter_1to2` and `/chatter_2to1`, baked into the image as `/demo_bridge.yaml` so the demo scripts pick it up without env overrides.
- Smoke tests: `ROS1_DISTRO`/`ROS2_DISTRO` env vars, `/ros_entrypoint.sh` existence + ability to source both ROS envs + expose `ros2`, plus 9 new demo-helper tests (4 scripts exist+executable, 4 `-h` prints `Usage:`, `/demo_bridge.yaml` exists). Total: 28 → 37.

### Removed
- `COPY config/ /config/` from Dockerfile and the `config directory exists` smoke test — the `/config/` directory was never read at runtime (entrypoint only loads `/bridge.yaml`). `config/*.yaml` files remain in the repo as reference examples and can still be consumed via `--build-arg BRIDGE_FILE=config/<file>.yaml`.

### Fixed
- **`script/entrypoint.sh` no longer hangs the runtime container when roscore is unreachable.** The unconditional `rosparam load /bridge.yaml` used to block container boot indefinitely — `compose up runtime` would sit there waiting for a ROS master that never arrives on a cold start. Wrapped the call in `timeout 2 rosparam list` and print a warning on stderr when the probe fails, then continue to `exec "${@}"`. Regression smoke test (`entrypoint.sh skips rosparam load when roscore unreachable`) asserts the warning path and command passthrough.
- **CI matrix did not include arm64.** PR #23 rebuilt `devel` from a multi-arch base for Jetson support, but `.github/workflows/main.yaml` never opted in to the template's arm64 build matrix (default is `linux/amd64` only). Pass `platforms: linux/amd64,linux/arm64` to `build-worker.yaml` so CI now actually verifies arm64 on every push, instead of relying on manual rsync-to-Jetson testing.
- **arm64 / Jetson `./build.sh test` failure (closes template #106).** Dockerfile's inline `bats-src` / `bats-extensions` / `lint-tools` stages had hardcoded `linux.x86_64` / `Linux-x86_64` download URLs, so on arm64 hosts they pulled unusable binaries and the `test` stage exited at `shellcheck -S warning /lint/*.sh`. Migrated to template's arch-aware pre-built test-tools image (v0.9.13 D plan): top-level `ARG TEST_TOOLS_IMAGE="test-tools:local"` default keeps local `./build.sh` flow unchanged (builds `Dockerfile.test-tools` into host Docker daemon); CI overrides to `ghcr.io/ycpss91255-docker/test-tools:v0.9.13` via `GITHUB_WORKFLOW_REF` parsing in `build-worker.yaml`. New `FROM ${TEST_TOOLS_IMAGE} AS test-tools-stage` alias; 4 `COPY --from=test-tools:local` → `--from=test-tools-stage`. 3 inline stages deleted, net ~15 lines removed.
- Restore `.env.example` (removed during APT-mirror refactor) so `setup.sh`'s IMAGE_NAME detection has its documented fallback.

## [v1.4.1] - 2026-03-25

### Changed
- move smoke/ to test/smoke/
- move READMEs to doc/, entrypoint.sh to script/

### Fixed
- update README directory structure and test counts (#1)

## [v1.4.0] - 2026-03-20

### Changed
- test: add script_help.bats for shell script -h/--help tests

## [v1.3.1] - 2026-03-19

### Added
- add stop.sh for stopping background containers

## [v1.3.0] - 2026-03-19

### Added
- auto down before up -d, remove stop.sh
- add stop.sh to clean up background containers

### Changed
- exec.sh use -t flag for target, args as command

## [v1.2.1] - 2026-03-19

### Changed
- remove lint-worker.yaml, lint runs in Dockerfile test stage

## [v1.2.0] - 2026-03-19

### Added
- add ShellCheck + Hadolint to Dockerfile test stage

## [v1.1.1] - 2026-03-18

- Initial release

## [v1.1.0] - 2026-03-18

### Changed
- add .hadolint.yaml to ignore inapplicable rules
- add ShellCheck and Hadolint static analysis

## [v1.0.0] - 2026-03-18

### Added
- add -h/--help support to all interactive scripts
- initial ROS 1/2 bridge container

### Changed
- unify help text to usage() function, add smoke test tables
- Add .env.example
- Add detach mode to run.sh and rewrite exec.sh
- initial commit

### Fixed
- revert assert_output back to assert_line in smoke test
- release-worker.yaml archive list and exec.sh bugs

