FROM ghcr.io/studyfranco/games-docker:proton-dotnet48

LABEL maintainer="studyfranco@gmail.com"

# Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
COPY --chmod=755 run.sh /opt/game/run.sh

ENV STEAM_APP_ID="298740" \
    WORLD_NAME="" \
    GAMECONFIG="/config/gameconfigs/SpaceEngineers-Dedicated.cfg"

EXPOSE 27016/udp 8080/tcp

# The server is up when its port (read in the config, the reference) is open
# First start: download + copy of the Proton prefix
HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
    CMD port=$(sed -n 's:.*<ServerPort>\([0-9]*\)</ServerPort>.*:\1:p' "${GAMECONFIG}") && awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${port}")$" || exit 1
