**[English](CHANGELOG.md)** | **[繁體中文](CHANGELOG.zh-TW.md)** | **[简体中文](CHANGELOG.zh-CN.md)** | **[日本語](CHANGELOG.ja.md)**

# 變更記錄

格式基於 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
版本號遵循 [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.4.1] - 2026-03-25

### 變更
- move smoke/ to test/smoke/
- move READMEs to doc/, entrypoint.sh to script/

### 修復
- update README directory structure and test counts (#1)

## [v1.4.0] - 2026-03-20

### 變更
- test: add script_help.bats for shell script -h/--help tests

## [v1.3.1] - 2026-03-19

### 新增
- add stop.sh for stopping background containers

## [v1.3.0] - 2026-03-19

### 新增
- auto down before up -d, remove stop.sh
- add stop.sh to clean up background containers

### 變更
- exec.sh use -t flag for target, args as command

## [v1.2.1] - 2026-03-19

### 變更
- remove lint-worker.yaml, lint runs in Dockerfile test stage

## [v1.2.0] - 2026-03-19

### 新增
- add ShellCheck + Hadolint to Dockerfile test stage

## [v1.1.1] - 2026-03-18

- Initial release

## [v1.1.0] - 2026-03-18

### 變更
- add .hadolint.yaml to ignore inapplicable rules
- add ShellCheck and Hadolint static analysis

## [v1.0.0] - 2026-03-18

### 新增
- add -h/--help support to all interactive scripts
- initial ROS 1/2 bridge container

### 變更
- unify help text to usage() function, add smoke test tables
- Add .env.example
- Add detach mode to run.sh and rewrite exec.sh
- initial commit

### 修復
- revert assert_output back to assert_line in smoke test
- release-worker.yaml archive list and exec.sh bugs

