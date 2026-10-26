FROM ghcr.io/studyfranco/games-docker:proton

LABEL maintainer="studyfranco@gmail.com"

# Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh /opt/game/run.sh
COPY --chmod=644 enshrouded_server_example.json /opt/game/enshrouded_server_example.json

ENV STEAM_APP_ID="2278520" \
    SERVER_NAME="EnshroudedServerByMe" \
    SERVER_PORT=15637 \
    SERVER_PASSWORD="" \
    SERVER_ADMIN_PASSWORD="" \
    MAX_PLAYERS=16 \
    VOICE_CHAT_MODE="" \
    ENABLE_VOICE_CHAT="" \
    ENABLE_TEXT_CHAT="" \
    GAMECONFIG="/config/gameconfigs/enshrouded_server.json"
ENV CONFIG_DIRS="${CONFIG_DIRS} /config/logs"

EXPOSE 15637/udp 27015/udp

# The server is up when its query port (read in the config, the reference) is open
# First start: download + Wine prefix creation
HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
    CMD port=$(jq -r '.queryPort' "${GAMECONFIG}") && awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${port}")$" || exit 1
