#!/usr/bin/env bash
# Build ros1_bridge via colcon with auto-detected MAKEFLAGS=-j.
#
# ros1_bridge's colcon compile peaks ~1.5-2 GB per parallel job from
# message-type template instantiation across many message packages.
# Pure -j$(nproc) OOMs on small-memory targets (Jetson Nano 4 GB,
# Jetson Orin 8 GB). Heuristic: min(nproc, mem_gb / 2). Override
# via BUILD_JOBS env var when the user knows their constraints.
# Refs ycpss91255-docker/ros1_bridge#79.
#
# `set -u` deliberately omitted: ROS setup.bash profile.d entries (roslaunch.sh
# in particular) reference unbound vars (ROS_MASTER_URI), and the original
# Dockerfile RUN this script replaces also used only `set -e` for that reason.
set -eo pipefail

main() {
  local cpu mem_gb mem_cap jobs

  cpu=$(nproc)
  mem_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)

  if [[ -z "${BUILD_JOBS:-}" ]]; then
    mem_cap=$(( mem_gb / 2 ))
    jobs="${cpu}"
    (( mem_cap < jobs )) && jobs="${mem_cap}"
    (( jobs < 1 )) && jobs=1
  else
    jobs="${BUILD_JOBS}"
  fi

  echo "[colcon] auto-detected -j${jobs} (cpu=${cpu}, mem=${mem_gb}GB)"

  # --print-jobs short-circuits — emit the detected line and exit. Used
  # by smoke tests to verify the heuristic without running colcon.
  if [[ "${1:-}" == "--print-jobs" ]]; then
    return 0
  fi

  # shellcheck disable=SC1090
  source "/opt/ros/${ROS1_DISTRO}/setup.bash"
  # shellcheck disable=SC1090
  source "/opt/ros/${ROS2_DISTRO}/setup.bash"

  cd /bridge_ws
  MAKEFLAGS="-j${jobs}" colcon build \
    --packages-select ros1_bridge \
    --cmake-args -DCMAKE_BUILD_TYPE=Release
}

main "$@"
