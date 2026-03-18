ARG IMAGE="osrf/ros:foxy-ros1-bridge"

############################## test tool sources ##############################
FROM bats/bats:latest AS bats-src

FROM alpine:latest AS bats-extensions
RUN apk add --no-cache git && \
    git clone --depth 1 -b v0.3.0 \
        https://github.com/bats-core/bats-support /bats/bats-support && \
    git clone --depth 1 -b v2.1.0 \
        https://github.com/bats-core/bats-assert  /bats/bats-assert

FROM alpine:latest AS lint-tools
RUN apk add --no-cache curl xz && \
    curl -fsSL \
        https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz \
        | tar -xJ -C /tmp && \
    mv /tmp/shellcheck-v0.10.0/shellcheck /usr/local/bin/shellcheck && \
    curl -fsSL -o /usr/local/bin/hadolint \
        https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64 && \
    chmod +x /usr/local/bin/hadolint

############################## runtime ##############################
FROM ${IMAGE} AS runtime

ARG BRIDGE_FILE="bridge.yaml"

COPY --chmod=0755 entrypoint.sh /entrypoint.sh
COPY --chmod=0644 "${BRIDGE_FILE}" /bridge.yaml
COPY --chmod=0644 config/ /config/

ENTRYPOINT ["/entrypoint.sh"]
CMD ["ros2", "run", "ros1_bridge", "parameter_bridge"]

############################## test (ephemeral) ##############################
FROM runtime AS test

# Install lint tools
COPY --from=lint-tools /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=lint-tools /usr/local/bin/hadolint /usr/local/bin/hadolint

# Lint: ShellCheck (.sh) + Hadolint (Dockerfile)
COPY .hadolint.yaml /lint/.hadolint.yaml
COPY Dockerfile /lint/Dockerfile
COPY *.sh /lint/
RUN shellcheck -S warning /lint/*.sh
RUN cd /lint && hadolint Dockerfile

# Install bats
COPY --from=bats-src /opt/bats /opt/bats
COPY --from=bats-src /usr/lib/bats /usr/lib/bats
COPY --from=bats-extensions /bats /usr/lib/bats
RUN ln -sf /opt/bats/bin/bats /usr/local/bin/bats

ENV BATS_LIB_PATH="/usr/lib/bats"

# Smoke test
COPY smoke_test/ /smoke_test/

RUN bats /smoke_test/
