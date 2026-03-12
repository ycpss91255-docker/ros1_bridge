ARG IMAGE="osrf/ros:foxy-ros1-bridge"

############################## bats sources ##############################
FROM bats/bats:latest AS bats-src

FROM alpine:latest AS bats-extensions
RUN apk add --no-cache git && \
    git clone --depth 1 -b v0.3.0 \
        https://github.com/bats-core/bats-support /bats/bats-support && \
    git clone --depth 1 -b v2.1.0 \
        https://github.com/bats-core/bats-assert  /bats/bats-assert

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

COPY --from=bats-src /opt/bats /opt/bats
COPY --from=bats-src /usr/lib/bats /usr/lib/bats
COPY --from=bats-extensions /bats /usr/lib/bats
RUN ln -sf /opt/bats/bin/bats /usr/local/bin/bats

ENV BATS_LIB_PATH="/usr/lib/bats"

COPY smoke_test/ /smoke_test/

RUN bats /smoke_test/
