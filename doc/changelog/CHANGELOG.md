**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Rebuild `devel` stage from `ros:foxy-ros-base-focal` (multi-arch) plus the ROS 1 snapshot apt repo instead of the amd64-only `osrf/ros:foxy-ros1-bridge`. Enables Jetson (arm64) support.
- `ENV ROS1_DISTRO=noetic` / `ENV ROS2_DISTRO=foxy` now baked into the image so downstream scripts can reference the distro names without hardcoding.
- Test stage lint target uses `COPY script/*.sh /lint/` (glob) to pick up new scripts automatically.

### Added
- `script/ros_entrypoint.sh` — osrf-compatible entrypoint that only sources both ROS distros (no `rosparam load`), available at `/ros_entrypoint.sh` in the image. The existing `/entrypoint.sh` remains the default `ENTRYPOINT`.
- Smoke tests: `ROS1_DISTRO`/`ROS2_DISTRO` env vars, `/ros_entrypoint.sh` existence + ability to source both ROS envs + expose `ros2`.

### Fixed
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

