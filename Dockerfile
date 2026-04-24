ARG IMAGE="ros:foxy-ros-base-focal"

############################## devel ##############################
FROM ${IMAGE} AS devel

# tools for adding ros1 snapshot apt repo
RUN apt-get update && apt-get install -q -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# fetch ros1 snapshot archive key into a dedicated keyring
RUN set -eux; \
    key='4B63CF8FDE49746E98FA01DDAD19BAB3CBF125EA'; \
    GNUPGHOME="$(mktemp -d)"; \
    export GNUPGHOME; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${key}"; \
    mkdir -p /usr/share/keyrings; \
    gpg --batch --export "${key}" > /usr/share/keyrings/ros1-snapshots-archive-keyring.gpg; \
    gpgconf --kill all; \
    rm -rf "${GNUPGHOME}"

# register ros1 noetic final snapshot apt source
RUN echo "deb [ signed-by=/usr/share/keyrings/ros1-snapshots-archive-keyring.gpg ] http://snapshots.ros.org/noetic/final/ubuntu focal main" \
    > /etc/apt/sources.list.d/ros1-snapshots.list

ENV ROS1_DISTRO=noetic
ENV ROS2_DISTRO=foxy

# install ROS 1 packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-noetic-ros-comm=1.17.4-1* \
        ros-noetic-roscpp-tutorials=0.10.3-1* \
        ros-noetic-rospy-tutorials=0.10.3-1* \
    && rm -rf /var/lib/apt/lists/*

# install ROS 2 packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-foxy-ros1-bridge=0.9.7-1* \
        ros-foxy-demo-nodes-cpp=0.9.4-1* \
        ros-foxy-demo-nodes-py=0.9.4-1* \
    && rm -rf /var/lib/apt/lists/*

ARG BRIDGE_FILE="bridge.yaml"

COPY --chmod=0755 script/entrypoint.sh /entrypoint.sh
COPY --chmod=0755 script/ros_entrypoint.sh /ros_entrypoint.sh
COPY --chmod=0644 "${BRIDGE_FILE}" /bridge.yaml

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

############################## runtime ##############################
FROM devel AS runtime

ENTRYPOINT ["/entrypoint.sh"]
CMD ["ros2", "run", "ros1_bridge", "parameter_bridge"]

############################## test (ephemeral) ##############################
FROM devel AS test

# Lint tools (from pre-built test-tools image built by build.sh)
COPY --from=test-tools:local /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=test-tools:local /usr/local/bin/hadolint /usr/local/bin/hadolint

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
COPY --from=test-tools:local /opt/bats /opt/bats
COPY --from=test-tools:local /usr/lib/bats /usr/lib/bats
RUN ln -sf /opt/bats/bin/bats /usr/local/bin/bats

ENV BATS_LIB_PATH="/usr/lib/bats"

# Smoke test
COPY template/test/smoke/test_helper.bash template/test/smoke/script_help.bats /smoke_test/
COPY test/smoke/ /smoke_test/

RUN bats /smoke_test/
