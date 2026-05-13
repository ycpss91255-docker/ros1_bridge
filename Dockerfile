# ROS2_DISTRO selects the ROS 2 base (humble | jazzy). Default
# `humble` matches setup.conf's [build] arg_4 default, which
# `./build.sh` and `./run.sh` always pass through, so direct
# `docker build` without `--build-arg ROS2_DISTRO=...` also works.
# CI overrides via the matrix in .github/workflows/main.yaml.
# Setting a default here silences BuildKit's `InvalidDefaultArgInFrom`
# warning that fired when `${IMAGE}` resolved to `ros:-ros-base` at
# parse-time default evaluation. Invalid values still fail explicitly
# inside the `case "${ROS2_DISTRO}"` blocks below (pip + runtime apt
# branches). To switch to jazzy, edit setup.conf [build] arg_4 (see
# README "Switch ROS 2 distro").
ARG ROS2_DISTRO=humble
ARG IMAGE="ros:${ROS2_DISTRO}-ros-base"
ARG TEST_TOOLS_IMAGE="test-tools:local"

############################## builder ##############################
# Heavy build stage. Source-builds Noetic ros_comm + ros1_bridge,
# keeps source + intermediate trees so downstream `devel` can reuse
# them for re-build / debug. Runtime stage does NOT inherit from this
# stage; it COPYs only the install trees out.
FROM ${IMAGE} AS builder

ARG ROS2_DISTRO
ENV ROS1_DISTRO=noetic
ENV ROS2_DISTRO=${ROS2_DISTRO}

# Override colcon build parallelism. Empty (default) = auto-detect from
# min(nproc, mem_gb/2). Pass `--build-arg BUILD_JOBS=N` when the heuristic
# mis-estimates (memory-constrained boards, large self-hosted runners
# wanting explicit caps, etc.). See #79.
ARG BUILD_JOBS=""

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
# Source + build_isolated / devel_isolated trees are KEPT so devel can
# `catkin_make_isolated` again after editing.
RUN env -u ROS_DISTRO ./src/catkin/bin/catkin_make_isolated \
        --install \
        --install-space /opt/ros/noetic \
        -DCMAKE_BUILD_TYPE=Release \
        --cmake-args -DROSCONSOLE_BACKEND=print

# Build ros1_bridge from source. Upstream `ros2/ros1_bridge` has only a
# `master` branch (no per-distro branches); all ROS 2 distros build from
# master per Open Robotics' release process.
WORKDIR /bridge_ws

RUN mkdir -p src \
    && cd src \
    && git clone https://github.com/ros2/ros1_bridge.git

# Build ros1_bridge — source / build / log trees KEPT so devel can rerun
# colcon build after editing src/ros1_bridge. MAKEFLAGS=-j is auto-detected
# inside colcon_build_bridge.sh from min(nproc, mem_gb/2) so the build
# scales across GHA runners, dev boxes, and Jetson hardware without OOM
# (refs #79). Override with `--build-arg BUILD_JOBS=N`.
COPY --chmod=0755 script/docker/colcon_build_bridge.sh /tmp/colcon_build_bridge.sh
RUN BUILD_JOBS="${BUILD_JOBS}" /tmp/colcon_build_bridge.sh

############################## devel ##############################
# Devel = builder + repo's scripts + bridge.yaml. Source trees still
# present at /noetic_ws/src and /bridge_ws/src/ros1_bridge — edit and
# rebuild in-place via `catkin_make_isolated` / `colcon build`.
FROM builder AS devel

ARG BRIDGE_FILE="bridge.yaml"

# Entrypoints stay at / (ENTRYPOINT below assumes /ros_entrypoint.sh).
COPY --chmod=0755 script/entrypoint.sh script/ros_entrypoint.sh /
# Demo helpers land in /root/demo/ -- combined with WORKDIR /root/demo below,
# users `./exec.sh` into the container, land directly inside this folder and
# `ls` shows the 4 demo scripts immediately. Closes #70.
COPY --chmod=0755 \
    script/ros1_server.sh script/ros1_client.sh \
    script/ros2_server.sh script/ros2_client.sh \
    script/demo_pub_ros1.py script/demo_pub_ros2.py \
    /root/demo/
# bridge.yaml is gitignored (per-clone operator pick from config/ros1_bridge/,
# see README "Bridge Configuration"). When the symlink is missing or broken
# on a fresh clone, fall back to config/ros1_bridge/demo_bridge.yaml so the
# doc'd Quick Start works without first creating the symlink. An explicit
# `--build-arg BRIDGE_FILE=config/ros1_bridge/<picked>.yaml` still wins; an
# explicit override that does not resolve fails loudly. Closes #65 / #70.
RUN --mount=type=bind,source=.,target=/ctx \
    if [ -f "/ctx/${BRIDGE_FILE}" ]; then \
        install -m 0644 "/ctx/${BRIDGE_FILE}" /bridge.yaml; \
    elif [ "${BRIDGE_FILE}" = "bridge.yaml" ]; then \
        echo "[Dockerfile] bridge.yaml symlink missing or broken; falling back to config/ros1_bridge/demo_bridge.yaml" >&2; \
        install -m 0644 /ctx/config/ros1_bridge/demo_bridge.yaml /bridge.yaml; \
    else \
        echo "[Dockerfile] BRIDGE_FILE='${BRIDGE_FILE}' is not a readable file in the build context" >&2; \
        exit 1; \
    fi
COPY --chmod=0644 config/ros1_bridge/demo_bridge.yaml /demo_bridge.yaml

WORKDIR /root/demo

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

############################## runtime ##############################
# Runtime = lean. `FROM ${IMAGE}` (= ros:${ROS2_DISTRO}-ros-base) means
# Python, Boost runtime libs, log4cxx, libssl etc. that ROS 2 itself
# depends on are already available — they are also what Noetic ros_comm
# and ros1_bridge link against (same major Boost ABI as the host distro
# ships, log4cxx not actually used at runtime since builder built with
# -DROSCONSOLE_BACKEND=print). empy / python3-pip / rosinstall are
# pure build-time helpers (message generation runs at build, not at
# load) so they are intentionally NOT installed here. Issue #59 has
# the architectural rationale.
#
# If the smoke test surfaces a missing .so at `parameter_bridge` load
# (ldd unresolved), add the minimum apt package here — do NOT regress
# to installing the full builder dep set.
FROM ${IMAGE} AS runtime

ARG ROS2_DISTRO
ENV ROS1_DISTRO=noetic
ENV ROS2_DISTRO=${ROS2_DISTRO}

# Runtime shared libs that Noetic ros_comm + ros1_bridge dynamically
# link against, but ros:${ROS2_DISTRO}-ros-base does not ship by
# default. Identified empirically by ldd-ing /opt/ros/noetic/lib/*.so
# and /bridge_ws/install/.../parameter_bridge from the builder image.
#
# Two distro splits:
#   - Boost major version: 1.74.0 on jammy (humble), 1.83.0 on noble (jazzy)
#   - time_t-64 transition (t64 suffix): noble adds t64 to some
#     packages (libboost-chrono, libpocofoundation, libgpgme); jammy
#     uses unsuffixed names. libboost-filesystem / -thread /
#     -program-options happen to NOT carry t64 even on noble.
#
# If a future ldd surfaces another missing .so, add the minimum
# package here. Do NOT regress to bulk-installing the full builder
# dep set; that defeats the lean-runtime split.
# hadolint ignore=SC2046
RUN apt-get update && apt-get install -y --no-install-recommends \
        $(case "${ROS2_DISTRO}" in \
            jazzy) echo \
                libboost-chrono1.83.0t64 \
                libboost-filesystem1.83.0 \
                libboost-program-options1.83.0 \
                libboost-thread1.83.0 \
                libpocofoundation80t64 \
                libgpgme11t64 \
                ;; \
            humble) echo \
                libboost-chrono1.74.0 \
                libboost-filesystem1.74.0 \
                libboost-program-options1.74.0 \
                libboost-thread1.74.0 \
                libpocofoundation80 \
                libgpgme11 \
                ;; \
            *) echo "unsupported ROS2_DISTRO: ${ROS2_DISTRO}" >&2; exit 1 ;; \
        esac) \
    && rm -rf /var/lib/apt/lists/*

# Pull the install trees out of builder. /opt/ros/noetic is the Noetic
# catkin install space; /bridge_ws/install is the colcon install for
# ros1_bridge. No build tools, no source, no catkin/colcon intermediate.
COPY --from=builder /opt/ros/noetic /opt/ros/noetic
COPY --from=builder /bridge_ws/install /bridge_ws/install

ARG BRIDGE_FILE="bridge.yaml"

# Same script COPY split as the devel stage. Closes #70.
COPY --chmod=0755 script/entrypoint.sh script/ros_entrypoint.sh /
COPY --chmod=0755 \
    script/ros1_server.sh script/ros1_client.sh \
    script/ros2_server.sh script/ros2_client.sh \
    script/demo_pub_ros1.py script/demo_pub_ros2.py \
    /root/demo/
# Same bridge.yaml fallback rule as the devel stage above. Closes #65 / #70.
RUN --mount=type=bind,source=.,target=/ctx \
    if [ -f "/ctx/${BRIDGE_FILE}" ]; then \
        install -m 0644 "/ctx/${BRIDGE_FILE}" /bridge.yaml; \
    elif [ "${BRIDGE_FILE}" = "bridge.yaml" ]; then \
        echo "[Dockerfile] bridge.yaml symlink missing or broken; falling back to config/ros1_bridge/demo_bridge.yaml" >&2; \
        install -m 0644 /ctx/config/ros1_bridge/demo_bridge.yaml /bridge.yaml; \
    else \
        echo "[Dockerfile] BRIDGE_FILE='${BRIDGE_FILE}' is not a readable file in the build context" >&2; \
        exit 1; \
    fi
COPY --chmod=0644 config/ros1_bridge/demo_bridge.yaml /demo_bridge.yaml

WORKDIR /root/demo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["ros2", "run", "ros1_bridge", "parameter_bridge"]

############################## devel-test (ephemeral) ##############################
# Resolves to test-tools:local (local ./build.sh builds Dockerfile.test-tools
# into the host Docker daemon) or ghcr.io/ycpss91255-docker/test-tools:vX.Y.Z
# (CI passes the matching template tag via --build-arg TEST_TOOLS_IMAGE=...).
FROM ${TEST_TOOLS_IMAGE} AS test-tools-stage

FROM devel AS devel-test

# Lint tools (from pre-built test-tools image; see TEST_TOOLS_IMAGE at top)
COPY --from=test-tools-stage /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=test-tools-stage /usr/local/bin/hadolint /usr/local/bin/hadolint

# Lint: ShellCheck (.sh) + Hadolint (Dockerfile)
COPY .hadolint.yaml /lint/.hadolint.yaml
COPY Dockerfile /lint/Dockerfile
COPY .base/script/docker/build.sh .base/script/docker/run.sh .base/script/docker/exec.sh .base/script/docker/stop.sh /lint/
COPY .base/script/docker/_lib.sh .base/script/docker/i18n.sh /lint/
COPY script/*.sh /lint/
COPY script/docker/*.sh /lint/
RUN shellcheck -S warning /lint/*.sh
RUN cd /lint && hadolint Dockerfile

# Bats + extensions (from pre-built test-tools image; bats-support / bats-assert
# are bundled into /usr/lib/bats, no separate stage needed)
COPY --from=test-tools-stage /opt/bats /opt/bats
COPY --from=test-tools-stage /usr/lib/bats /usr/lib/bats
RUN ln -sf /opt/bats/bin/bats /usr/local/bin/bats

ENV BATS_LIB_PATH="/usr/lib/bats"

# Smoke test
COPY .base/test/smoke/test_helper.bash .base/test/smoke/script_help.bats /smoke_test/
COPY test/smoke/ /smoke_test/

RUN bats /smoke_test/

############################## runtime-test (ephemeral) ##############################
# Install-check smoke for the runtime image (template v0.21.1+ #243).
# Default smoke verifies USER + bash on PATH. Override per-repo via
# build_args: RUNTIME_SMOKE_CMD=<command> (constraint: CLI-only, no
# GUI binaries that init Qt / OGRE on --version / --help).
#
# `sh -c` wrapper required: bare `RUN ${ARG}` word-splits operators
# (&&, ||) and nested quotes. The wrapper passes the value as a
# single string for sh to parse normally.
FROM runtime AS runtime-test

ARG RUNTIME_SMOKE_CMD='whoami && bash --version'
RUN sh -c "${RUNTIME_SMOKE_CMD}"
