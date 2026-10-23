FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

# Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh /opt/game/run.sh

ENV STEAM_APP_ID="1690800" \
    SERVER_PORT=7777 \
    SERVER_MESSAGING_PORT=8888 \
    MAX_PLAYERS=4 \
    AUTOSAVE_NUM=5 \
    MAX_OBJECTS=2162688 \
    MAX_TICK_RATE=30 \
    TIMEOUT=30 \
    SERVER_STREAMING="true" \
    DISABLE_SEASONAL_EVENTS="false" \
    MULTIHOME="::"
ENV CONFIG_DIRS="${CONFIG_DIRS} /config/logs"

EXPOSE 7777/udp 7777/tcp 8888/tcp

# The server is up when its HTTPS API says healthy (first start: download of the server)
HEALTHCHECK --interval=30s --timeout=10s --start-period=15m --retries=3 \
    CMD curl -kfsS -m 5 -X POST "https://127.0.0.1:${SERVER_PORT}/api/v1" -H "Content-Type: application/json" \
        -d '{"function":"HealthCheck","data":{"clientCustomData":""}}' | jq -e '.data.health == "healthy"' > /dev/null || exit 1
