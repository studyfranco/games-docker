FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

# Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh /opt/game/run.sh

ENV STEAM_APP_ID="443030" \
    SERVER_NAME="ConanExilesServerByMe" \
    SERVER_PORT=7777 \
    SERVER_QUERY_PORT=27015 \
    SERVER_PASSWORD="" \
    SERVER_ADMIN_PASSWORD="" \
    MAX_PLAYERS=40 \
    RCON_PORT=25575 \
    RCON_PASSWORD="" \
    MOD_IDS=""
ENV CONFIG_DIRS="${CONFIG_DIRS} /config/logs"

EXPOSE 7777/udp 7778/udp 27015/udp 25575/tcp

# The server is up when its game port is open (first start: download of the server)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
    CMD awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${SERVER_PORT}")$" || exit 1
