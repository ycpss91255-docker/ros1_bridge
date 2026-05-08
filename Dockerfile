# ROS2_DISTRO is required (no default) — caller must supply via build_arg.
# main.yaml provides it via the matrix; setup.conf via [build] arg_4;
# direct `docker build` requires `--build-arg ROS2_DISTRO=humble|jazzy`.
ARG ROS2_DISTRO
ARG IMAGE="ros:${ROS2_DISTRO}-ros-base"
ARG TEST_TOOLS_IMAGE="test-tools:local"

############################## devel ##############################
FROM ${IMAGE} AS devel

# Re-declare ARGs needed inside this stage (FROM-scoped ARGs don't carry).
ARG ROS2_DISTRO
ENV ROS1_DISTRO=noetic
ENV ROS2_DISTRO=${ROS2_DISTRO}

# Bootstrap deps for source-building Noetic on jammy / noble. ROS 1 Noetic
# has no apt packages outside focal, so we build ros_comm from source.
# See issue #53 for full rationale.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        python3-pip \
        python3-rosdep \
        python3-vcstool \
        python3-catkin-pkg \
        python3-nose \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Pip-only path keeps jammy and noble identical:
#   - empy 3.3.4: system python3-empy is 4.x; Noetic em.py needs 3.x
#   - rosinstall + rosinstall-generator: dropped from noble apt
#   - --break-system-packages: required on noble (PEP 668), unrecognized
#     by pip 22 on jammy — branch on ROS2_DISTRO and intentionally
#     word-split the empty/non-empty value into pip args.
# hadolint ignore=SC2086
RUN case "${ROS2_DISTRO}" in \
        jazzy) BSP="--break-system-packages" ;; \
        humble) BSP="" ;; \
        *) echo "unsupported ROS2_DISTRO: ${ROS2_DISTRO}" >&2; exit 1 ;; \
    esac; \
    pip3 install --no-cache-dir ${BSP} \
        'empy==3.3.4' \
        rosinstall \
        rosinstall-generator

# rosdep init may already be done in the ROS base image; tolerate it.
RUN rosdep init 2>/dev/null || true \
    && rosdep update --rosdistro=noetic

# Fetch + build Noetic ros_comm from source. Installs to /opt/ros/noetic
# to keep script path conventions (ros_entrypoint.sh, ros1_server.sh, …).
WORKDIR /noetic_ws

RUN rosinstall_generator ros_comm \
        --rosdistro noetic \
        --deps \
        --tar \
        > noetic-ros_comm.rosinstall \
    && mkdir -p src \
    && vcs import --input noetic-ros_comm.rosinstall ./src

RUN apt-get update \
    && rosdep install --from-paths ./src --ignore-src --rosdistro noetic -y \
        --skip-keys "python3-catkin-pkg-modules python3-rosdep-modules python3-rosdistro-modules" \
    && rm -rf /var/lib/apt/lists/*

# Two patches needed for the build to succeed on both jammy and noble:
#   1. `env -u ROS_DISTRO` — base image sets ROS_DISTRO=humble/jazzy;
#      Noetic's setup.bash then prints a warning to stdout that catkin's
#      environment_cache.py ast.literal_evals and trips on SyntaxError.
#   2. ROSCONSOLE_BACKEND=print — system log4cxx 1.x has shared_ptr API
#      incompatible with Noetic's log4cxx 0.10-era code. The `print`
#      backend writes to stderr only, sufficient for ros1_bridge use.
# Build + drop source/intermediate in one RUN — Docker layers are
# incremental, so a separate cleanup RUN wouldn't shrink the image.
RUN env -u ROS_DISTRO ./src/catkin/bin/catkin_make_isolated \
        --install \
        --install-space /opt/ros/noetic \
        -DCMAKE_BUILD_TYPE=Release \
        --cmake-args -DROSCONSOLE_BACKEND=print \
    && rm -rf /noetic_ws/src \
        /noetic_ws/build_isolated \
        /noetic_ws/devel_isolated \
        /noetic_ws/noetic-ros_comm.rosinstall

# Build ros1_bridge from source. Upstream `ros2/ros1_bridge` has only a
# `master` branch (no per-distro branches); all ROS 2 distros build from
# master per Open Robotics' release process.
WORKDIR /bridge_ws

RUN mkdir -p src \
    && cd src \
    && git clone https://github.com/ros2/ros1_bridge.git

# Build ros1_bridge + drop sources/intermediates in the same RUN.
RUN bash -c "set -e \
    && source /opt/ros/${ROS1_DISTRO}/setup.bash \
    && source /opt/ros/${ROS2_DISTRO}/setup.bash \
    && cd /bridge_ws \
    && MAKEFLAGS='-j2' colcon build \
        --packages-select ros1_bridge \
        --cmake-args -DCMAKE_BUILD_TYPE=Release" \
    && rm -rf /bridge_ws/src /bridge_ws/build /bridge_ws/log

ARG BRIDGE_FILE="bridge.yaml"

COPY --chmod=0755 script/ /
COPY --chmod=0644 "${BRIDGE_FILE}" /bridge.yaml
COPY --chmod=0644 config/demo_bridge.yaml /demo_bridge.yaml

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

############################## runtime ##############################
FROM devel AS runtime

ENTRYPOINT ["/entrypoint.sh"]
CMD ["ros2", "run", "ros1_bridge", "parameter_bridge"]

############################## test (ephemeral) ##############################
# Resolves to test-tools:local (local ./build.sh builds Dockerfile.test-tools
# into the host Docker daemon) or ghcr.io/ycpss91255-docker/test-tools:vX.Y.Z
# (CI passes the matching template tag via --build-arg TEST_TOOLS_IMAGE=...).
FROM ${TEST_TOOLS_IMAGE} AS test-tools-stage

FROM devel AS test

# Lint tools (from pre-built test-tools image; see TEST_TOOLS_IMAGE at top)
COPY --from=test-tools-stage /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=test-tools-stage /usr/local/bin/hadolint /usr/local/bin/hadolint

# Lint: ShellCheck (.sh) + Hadolint (Dockerfile)
COPY .hadolint.yaml /lint/.hadolint.yaml
COPY Dockerfile /lint/Dockerfile
COPY template/script/docker/build.sh template/script/docker/run.sh template/script/docker/exec.sh template/script/docker/stop.sh /lint/
COPY template/script/docker/_lib.sh template/script/docker/i18n.sh /lint/
COPY script/*.sh /lint/
RUN shellcheck -S warning /lint/*.sh
RUN cd /lint && hadolint Dockerfile

# Bats + extensions (from pre-built test-tools image; bats-support / bats-assert
# are bundled into /usr/lib/bats, no separate stage needed)
COPY --from=test-tools-stage /opt/bats /opt/bats
COPY --from=test-tools-stage /usr/lib/bats /usr/lib/bats
RUN ln -sf /opt/bats/bin/bats /usr/local/bin/bats

ENV BATS_LIB_PATH="/usr/lib/bats"

# Smoke test
COPY template/test/smoke/test_helper.bash template/test/smoke/script_help.bats /smoke_test/
COPY test/smoke/ /smoke_test/

RUN bats /smoke_test/
