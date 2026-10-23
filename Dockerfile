FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

# Game scripts run by /init.sh, update-check and backup, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh update-hook.sh backup-hook.sh palworld-api.sh /opt/game/

ENV STEAM_APP_ID="2394010" \
    SERVER_NAME="PalworldServerByMe" \
    SERVER_PORT=8211 \
    SERVER_QUERY_PORT=27015 \
    SERVER_PASSWORD="" \
    SERVER_ADMIN_PASSWORD="" \
    MAX_PLAYERS=32 \
    MAX_PLAYERS_COOP=32 \
    MAX_PLAYERS_GUILD=32 \
    RCON_PORT=25575 \
    REST_API_PORT=8212 \
    UPDATE_RESTART_DELAY=300
ENV CONFIG_DIRS="${CONFIG_DIRS} /config/logs"

EXPOSE 8211/udp 27015/udp

# The server is up when its game port is open (first start: download of the server)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
    CMD awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${SERVER_PORT}")$" || exit 1
