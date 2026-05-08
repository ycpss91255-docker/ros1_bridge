**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Fresh-clone build no longer fails when `bridge.yaml` symlink is absent** (closes [#65](https://github.com/ycpss91255-docker/ros1_bridge/issues/65)). Pre-fix, `Dockerfile` did `COPY --chmod=0644 "${BRIDGE_FILE}" /bridge.yaml` with `BRIDGE_FILE` defaulting to the gitignored `bridge.yaml` symlink — a brand-new clone has no symlink, so `./build.sh` and `./run.sh` failed with `failed to compute cache key: failed to calculate checksum of ref ...: "/bridge.yaml": not found` before the user reached the "Bridge Configuration" section that documents the symlink rule. Replaced the `COPY` in both `devel` and `runtime` stages with a `RUN --mount=type=bind,source=.,target=/ctx` block that picks `/ctx/${BRIDGE_FILE}` if it resolves to a regular file (covers both the default symlink-present path and any explicit `--build-arg BRIDGE_FILE=config/<picked>.yaml`), falls back to `config/demo_bridge.yaml` when `BRIDGE_FILE=bridge.yaml` (the default) doesn't resolve, and fails loudly when an explicit override doesn't resolve. CI's `BRIDGE_FILE=config/scan_bridge.yaml` build arg has been dropped from `.github/workflows/main.yaml` so every CI run exercises the fallback path under regression coverage. Added `bridge.yaml is non-empty (fresh-clone fallback regression #65)` smoke test in `test/smoke/ros_env.bats` to catch the corner case where the bind-mount cp produces an empty file. 4-language READMEs updated: TL;DR + Quick Start mention the optional `ln -sf config/<picked>.yaml bridge.yaml` step explicitly with a fallback note, and the "Bridge Configuration" section's intro now states the fallback rule. The generic template-side companion (a `script/pre-build.sh` opt-in hook for repo-specific UX hints) is filed separately as [template#248](https://github.com/ycpss91255-docker/template/issues/248).

### Changed
- README aligned to the canonical `template/` framework: added the GitHub Actions CI status badge, promoted the inline `> TL;DR` blockquote into a `## TL;DR` H2 section, added a new `## Overview` H2 (motivation paragraph distilled from the old TL;DR + the duplicate "Why source-build" Features bullet, which is now removed), and extended the table of contents to list `TL;DR` / `Overview` / `Smoke Tests`. The Directory Structure tree was corrected to point the four wrapper symlinks at `template/script/docker/<name>` (matching the actual symlink targets) and the obsolete root `.template_version` row was dropped — version tracking has lived in `template/.version` since the v0.16.0 subtree pull. No code, Dockerfile, or workflow changes; this is the reference application of the framework alignment that other downstream READMEs will follow.
- **Default `ROS2_DISTRO` is now `humble`** (was `jazzy` briefly between PR #61 and this one). Updated both `Dockerfile`'s `ARG ROS2_DISTRO=humble` default and `setup.conf [build] arg_4 = ROS2_DISTRO=humble`. CI matrix still builds both `humble` and `jazzy` shards in parallel, so the published `ghcr.io/ycpss91255-docker/ros1_bridge-{humble,jazzy}` images are unchanged.
- 4-language READMEs cleaned up: dropped two non-distinguishing feature bullets ("Dual entrypoints" — implementation detail; "Smoke Test" — baseline expectation, not a feature). Added a "Switch ROS 2 distro" section explaining how to flip between `humble` and `jazzy` (edit `setup.conf [build] arg_4` for the wrapper path; `--build-arg ROS2_DISTRO=...` for direct `docker build`) and how that interacts with CI matrix builds (matrix is the source of truth for published images, setup.conf only affects local builds).
- Set `ARG ROS2_DISTRO` default in `Dockerfile` to match `setup.conf [build] arg_4` (originally landed as `jazzy` in #61, now `humble` per this PR). The setup.conf default is what `./build.sh` and `./run.sh` always feed to BuildKit, so the wrapper path is unchanged; what changes is that direct `docker build` (without `--build-arg ROS2_DISTRO=...`) now picks up the default instead of failing, and BuildKit no longer prints two `InvalidDefaultArgInFrom: Default value for ARG ${IMAGE} results in empty or invalid base image name` warnings (one per `FROM ${IMAGE} AS …` in the Dockerfile). Invalid values are still rejected at the runtime `case "${ROS2_DISTRO}"` branches inside `RUN` steps.
- **Dockerfile restructured into `builder` / `devel` / `runtime` / `test` stages** (closes [#59](https://github.com/ycpss91255-docker/ros1_bridge/issues/59)). The previous layout had `runtime` defined as `FROM devel AS runtime`, which forced `devel` to drop its source trees in the same RUN that built them (otherwise `runtime` carried the source bloat). That made `devel` unusable for the standard "edit Noetic / `ros1_bridge` source, rebuild, retest" workflow. New layout:
  - `builder` (`FROM ${IMAGE}`) — full build deps + Noetic `ros_comm` + `ros1_bridge` source-built. Source / build_isolated / devel_isolated / colcon build / log trees are KEPT.
  - `devel` (`FROM builder`) — adds `script/` + `bridge.yaml` + entrypoint. Source available at `/noetic_ws/src/` and `/bridge_ws/src/ros1_bridge/`; rebuild via `env -u ROS_DISTRO ./src/catkin/bin/catkin_make_isolated --install --install-space /opt/ros/noetic` (Noetic) or `cd /bridge_ws && colcon build --packages-select ros1_bridge` (`ros1_bridge`).
  - `runtime` (`FROM ${IMAGE}`, NOT `FROM devel`) — `COPY --from=builder /opt/ros/noetic /opt/ros/noetic` + `COPY --from=builder /bridge_ws/install /bridge_ws/install` + repo's `script/` + `bridge.yaml` + entrypoint. No build tools, no source, no catkin/colcon intermediate. Local verification on jazzy shows the runtime image at ~938MB vs devel/test ~2GB (≈ 1.1GB saved per arch).
  - `runtime` apt installs the small set of shared libs the source-built Noetic `.so` files dynamically link against but `ros:${ROS2_DISTRO}-ros-base` does not ship by default — empirically `libboost-{chrono,filesystem,program_options,thread}`, `libpoco-foundation`, `libgpgme`. Boost major version + the noble `t64` (time_t-64bit) suffix differ between jammy and noble, so the package list is `case`-branched on `ROS2_DISTRO`. ROS 2 runtime libs (Python, libssl etc.) are inherited from the base image.
  - `test` (`FROM devel AS test`) — unchanged. Runs ShellCheck + Hadolint + bats smoke against the devel stage.
- **Fix `script/entrypoint.sh` source-propagation bug surfaced by #59 verification.** `bash`'s `source FILE` (without explicit args) propagates the calling script's positional parameters to the sourced file. `/entrypoint.sh` used to call `source /opt/ros/${ROS1_DISTRO}/setup.bash` without trailing `--`, so when CMD ended in `--help` (or any `--flag` arg), catkin's `_setup_util.py "$@"` saw `--help`, printed argparse usage to stdout, and the wrapper sourced that usage as shell — the container died with `setup.sh.<rand>: line 1: usage:: command not found` and exit 127. `script/ros_entrypoint.sh` already had the `--` (intentional from osrf convention); `entrypoint.sh` was missing it. New regression smoke test `entrypoint.sh handles --help in CMD without source-propagation error` guards against drift.
- Upgrade `template/` subtree to [v0.20.1](https://github.com/ycpss91255-docker/template/releases/tag/v0.20.1); pin `main.yaml` workflows to `@v0.20.1` and bump `test_tools_version` from `v0.11.0` to `v0.20.1` (closes [#55](https://github.com/ycpss91255-docker/ros1_bridge/issues/55)). The `test_tools_version` pin had drifted nine template releases behind the subtree, so CI was lint/smoke-testing today's code against a stale ShellCheck / Hadolint / bats toolchain. Bringing the pin back in step with `template/.version` per the standard `make upgrade` flow. v0.20.1 highlights from the template release notes:
  - new `template/.github/workflows/publish-worker.yaml` reusable workflow for repos that want to publish a foundational image to GHCR (opt-in: callers add `call-publish` to their `main.yaml`; this repo does not opt in).
  - `setup.sh` improvement (template release notes).
- **BREAKING — Foxy retired; Humble + Jazzy via source-built Noetic + `ros1_bridge`** (closes [#53](https://github.com/ycpss91255-docker/ros1_bridge/issues/53)). The `ros:foxy-ros-base-focal` base + ROS 1 snapshot apt repo + apt-installed `ros-foxy-ros1-bridge` is replaced with `ros:${ROS2_DISTRO}-ros-base` (humble or jazzy, selected via `ARG ROS2_DISTRO`) + Noetic `ros_comm` source-built into `/opt/ros/noetic/` (via `rosinstall_generator` tarballs + `catkin_make_isolated`) + `ros1_bridge` source-built from `ros2/ros1_bridge` master into `/bridge_ws/install/` (via `colcon build`). Both Foxy (EOL 2023-05) and the apt-installed Noetic path (focal-only) are no longer supported by Open Robotics; `ros-jazzy-ros1-bridge` does not exist; the chained DDS workaround (`humble|jazzy ↔ foxy ↔ noetic`) was empirically ruled out due to Fast-DDS major-version skew + REP-2011 type-hash mismatches (full investigation in #53). Notable details:
  - `Dockerfile`: required `ARG ROS2_DISTRO` (no default — caller must supply); two patches needed for Noetic to build on jammy/noble: `env -u ROS_DISTRO` (avoids catkin's `environment_cache.py` ast crash from base-image-set `ROS_DISTRO`) and `-DROSCONSOLE_BACKEND=print` (works around system log4cxx 1.x shared_ptr API incompatibility); `--break-system-packages` runtime-detected for noble pip 23+ (PEP 668).
  - `script/{entrypoint,ros_entrypoint,ros1_server,ros2_server}.sh`: source `/bridge_ws/install/setup.bash` overlay in addition to `/opt/ros/${ROS2_DISTRO}/setup.bash` (source-built `ros1_bridge` is not under the distro share tree).
  - `.github/workflows/main.yaml`: builds matrix across `[humble, jazzy]`; `image_name: ros1_bridge-${{ matrix.ros2_distro }}` keeps registry tags unambiguous (`ros1_bridge-humble:devel`, `ros1_bridge-jazzy:devel`); release archive prefix matches. Adds a stable `ci-summary` umbrella job (`needs: call-docker-build` + `if: always()` + asserts `result == success`) so branch protection's `required_status_checks` can pin a single name regardless of how many distros the matrix grows to — adding kilted/iron later won't require touching the protection rule.
  - `setup.conf`: `[build] arg_4 = ROS2_DISTRO=jazzy` selects the local default for `./build.sh` / `./run.sh`. CI overrides via the matrix.
  - `test/smoke/ros_env.bats`: distro-agnostic via `${ROS1_DISTRO}` / `${ROS2_DISTRO}` env vars; `ROS2_DISTRO` test now accepts `humble|jazzy` and rejects unset/unsupported values; `ros1_bridge package is available` now sources `/bridge_ws/install/setup.bash` so `ros2 pkg list` finds the source-built package.
- **BREAKING: `setup.conf.local` collapsed back into `<repo>/setup.conf`** as part of upgrading template subtree to [v0.16.0](https://github.com/ycpss91255-docker/template/releases/tag/v0.16.0) (template #201). Pre-v0.16.0 the per-repo override lived at `setup.conf.local` (committed) while `setup.conf` was a gitignored derived snapshot. Post-v0.16.0 there is a single committed `<repo>/setup.conf` user-override file. Migration: ran `.claude/scripts/migrate-local-to-setupconf.sh` upstream, which renamed `setup.conf.local` to `setup.conf` in place and dropped the obsolete `setup.conf` line from `.gitignore`. The v0.16.0 template subtree pull then re-syncs `.gitignore` (adds `setup.conf.local` so legacy files don't drift back). Other v0.16.0 highlights:
  - `setup.sh` bootstrap fix: fresh `apply` against an empty repo now correctly emits the workspace mount line in `compose.yaml` (template #201 regression test).
  - new `[additional_contexts]` section in `setup.conf` for compose's `build.additional_contexts:` (template #199). Empty in this repo, no behavior change.
  - per-section parameter coverage tests added upstream (template #202).
- Promote `template/` subtree pin from `v0.11.0-rc1` to [v0.11.0](https://github.com/ycpss91255-docker/template/releases/tag/v0.11.0). No code delta between rc1 and stable in the template subtree (rc1 was the validation tag); `main.yaml` now pins workflows to `@v0.11.0` and passes `test_tools_version: v0.11.0`.

## [v1.6.0] - 2026-04-27

### Changed
- **BREAKING — `bridge.yaml` is no longer tracked.** It is now a per-clone symlink the operator points at one of `config/*.yaml` before building. Demo configs split into two new files: `config/demo_services_1to2.yaml` (ROS 1 → ROS 2 services) and `config/demo_services_2to1.yaml` (ROS 2 → ROS 1 services). The old `bridge.yaml` (which mixed `/scan` topic + service demos and emitted "no conversion for type" errors at runtime because the type pairs aren't compiled into stock foxy `ros1_bridge`) is removed; its `/scan` content was already a duplicate of `config/scan_bridge.yaml`. Migration: `ln -sf config/<picked>.yaml bridge.yaml` before `./build.sh`. 4-language READMEs updated with the symlink table.
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

