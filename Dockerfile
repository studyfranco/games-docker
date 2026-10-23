FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

ARG CONTAINER_USER=steam
ARG DEBIAN_FRONTEND=noninteractive

USER root

# Libraries of the Valheim server (libpulse0 for the crossplay)
RUN set -x \
    && apt update \
    && apt install -y libatomic1 libpulse0 --no-install-recommends \
    && apt clean \
    && rm -rf /var/cache/* /var/lib/apt/lists/* /var/log/* /var/tmp/* /tmp/*

USER ${CONTAINER_USER}

# Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh /opt/game/run.sh

ENV STEAM_APP_ID="896660" \
    SERVER_NAME="ValheimServerByMe" \
    SERVER_PORT=2456 \
    SERVER_PASSWORD="" \
    WORLD_NAME="Dedicated" \
    PUBLIC=1 \
    CROSSPLAY="false" \
    PRESET="" \
    MODIFIERS="" \
    SET_KEYS="" \
    SAVE_INTERVAL=1800

EXPOSE 2456/udp 2457/udp

# The server is up when its game port is open (first start: download of the server)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
    CMD awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${SERVER_PORT}")$" || exit 1
