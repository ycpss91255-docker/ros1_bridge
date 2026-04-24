**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Upgrade `template/` subtree to [v0.10.0-rc2](https://github.com/ycpss91255-docker/template/releases/tag/v0.10.0-rc2). Bundles:
  - **Compose `runtime` service** auto-emitted by `setup.sh` when Dockerfile declares `FROM … AS runtime` (closes template #108). `./run.sh -t runtime` no longer errors with "no such service".
  - **`run.sh` arg realignment** (closes template #118, BREAKING): target is now `-t/--target` flag (default `devel`); positional args become CMD passthrough (empty → Dockerfile CMD, non-empty → override); `-d + cmd` → exit 2 error. `./run.sh` bare unchanged (devel bash). Migration inside this repo: `./run.sh runtime` now written as `./run.sh -t runtime` (auto-runs `parameter_bridge` attached). `./run.sh -t runtime bash` drops into runtime shell for debug.
  - **arm64 test-tools** hotfix — `Dockerfile.test-tools` `ARG TARGETARCH=amd64` default used to shadow BuildKit's auto-inject (moby/buildkit#3403), so `:v0.9.13` / `:v0.10.0-rc1` GHCR arm64 variants shipped x86_64 shellcheck / hadolint. v0.10.0-rc2 drops the default; arm64 binaries are now genuinely aarch64 (verified via `docker cp` + `file`).
  - Intermediate releases (v0.9.11/12/13, v0.10.0-rc1) are superseded; this PR pins `main.yaml` directly to `@v0.10.0-rc2`.
- Pin `main.yaml` reusable workflows to [`@v0.10.0-rc2`](https://github.com/ycpss91255-docker/template/releases/tag/v0.10.0-rc2).
- Rebuild `devel` stage from `ros:foxy-ros-base-focal` (multi-arch) plus the ROS 1 snapshot apt repo instead of the amd64-only `osrf/ros:foxy-ros1-bridge`. Enables Jetson (arm64) support.
- `ENV ROS1_DISTRO=noetic` / `ENV ROS2_DISTRO=foxy` now baked into the image so downstream scripts can reference the distro names without hardcoding.
- Test stage lint target uses `COPY script/*.sh /lint/` (glob) to pick up new scripts automatically.
- Bridge YAML examples now document the full `parameter_bridge` schema: `bridge.yaml` ships `services_1_to_2` / `services_2_to_1` entries and an inline QoS block on `/scan`; `config/scan_bridge.yaml` and `config/release_bridge.yaml` set sensor-data QoS (BEST_EFFORT for image streams, RELIABLE for `camera_info`). READMEs in all four languages note the topic (ROS 2) vs service (ROS 1) `type` format asymmetry.
- **Split `devel` and `runtime` into separate stages (USER-VISIBLE BEHAVIOR CHANGE).** `devel` CMD is now `bash` — `./run.sh` drops into an interactive shell instead of auto-launching `parameter_bridge`. `devel` ENTRYPOINT is `/ros_entrypoint.sh` (sources ROS1+ROS2 env only, no `rosparam load`) so the shell is usable immediately. The new `runtime` stage (`FROM devel`) keeps `CMD ["ros2", "run", "ros1_bridge", "parameter_bridge"]` and switches ENTRYPOINT back to `/entrypoint.sh` (which does `rosparam load /bridge.yaml` before launch) for production-style auto-bridge deployments. CI builds both (`build_runtime: true` in `main.yaml`). Note: `./run.sh runtime` does not yet work because the auto-generated `compose.yaml` does not emit a `runtime` service (tracked upstream in template); invoke runtime via direct `docker build --target runtime && docker run` until template provides this.

### Added
- `script/ros_entrypoint.sh` — osrf-compatible entrypoint that only sources both ROS distros (no `rosparam load`), available at `/ros_entrypoint.sh` in the image. `devel` stage uses this as its `ENTRYPOINT`; `runtime` stage keeps `/entrypoint.sh` (with `rosparam load`).
- Smoke tests: `ROS1_DISTRO`/`ROS2_DISTRO` env vars, `/ros_entrypoint.sh` existence + ability to source both ROS envs + expose `ros2`.

### Removed
- `COPY config/ /config/` from Dockerfile and the `config directory exists` smoke test — the `/config/` directory was never read at runtime (entrypoint only loads `/bridge.yaml`). `config/*.yaml` files remain in the repo as reference examples and can still be consumed via `--build-arg BRIDGE_FILE=config/<file>.yaml`.

### Fixed
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

