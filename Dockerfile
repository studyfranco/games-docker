FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

# Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh /opt/game/run.sh

ENV STEAM_APP_ID="3017300" \
    SERVER_NAME="SoulmaskServerByMe" \
    SERVER_PORT=8777 \
    SERVER_QUERY_PORT=27015 \
    SERVER_PASSWORD="" \
    SERVER_ADMIN_PASSWORD="" \
    MAX_PLAYERS=32 \
    RCON_PORT="" \
    RCON_PASSWORD="" \
    ECHO_PORT=18888 \
    BACKUP_INTERVAL=900 \
    SAVE_INTERVAL=600 \
    GAME_MODE="pve" \
    SERVER_LEVEL="Level01_Main" \
    SERVER_ID=1 \
    MAIN_SERVER_PORT=20000 \
    TO_MAIN_SERVER="" \
    MOD_IDS="" \
    BACKUP_DIRS="saves gameconfigs gameplayconfig savesAccount"
ENV CONFIG_DIRS="${CONFIG_DIRS} /config/gameplayconfig /config/savesAccount /config/logs"

EXPOSE 8777/udp 27015/udp 20000/tcp

# The server is up when its game port is open (first start: download of the server)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
    CMD awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${SERVER_PORT}")$" || exit 1
