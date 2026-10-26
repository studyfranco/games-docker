FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

# Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh /opt/game/run.sh

ENV STEAM_APP_ID="1348640" \
    SERVER_NAME="FrozenFlameServer" \
    SERVER_PORT=7779 \
    SERVER_QUERY_PORT=7780 \
    SERVER_PASSWORD="" \
    SERVER_ADMIN_PASSWORD="" \
    RCON_PORT=27017 \
    MAX_PLAYERS=10 \
    FREE_PVP="true" \
    DAY_DURATION=3600 \
    GAME_CONFIG_URL="https://raw.githubusercontent.com/DreamsideInteractive/FrozenFlameServer/main/Game.ini"
ENV CONFIG_DIRS="${CONFIG_DIRS} /config/logs"

EXPOSE 7779/udp 7780/udp 27017/tcp

# The server is up when its game port is open (first start: download of the server)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
    CMD awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${SERVER_PORT}")$" || exit 1
