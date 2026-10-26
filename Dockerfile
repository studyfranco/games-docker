FROM debian:testing-slim

LABEL maintainer="studyfranco@gmail.com"
# Used by the host cron to find the containers to update
LABEL games-docker.update-check="true"

ARG CONTAINER_USER=steam
ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    USER="${CONTAINER_USER}"
ENV HOME="/home/${USER}"
ENV STEAMCMD_PATH="/opt/steamcmd" \
    STEAMCMD_WORKING_PATH="${HOME}/steamcmd" \
    STEAM_SDK64_PATH="${HOME}/.steam/sdk64" \
    STEAM_SDK32_PATH="${HOME}/.steam/sdk32" \
    STEAM_APP_ID="" \
    GAME_PLATFORM="" \
    GAME_BRANCH="" \
    SKIP_UPDATE="false" \
    EXTRA_ARGS="" \
    BACKUP_RETENTION=10 \
    BACKUP_DIRS="saves gameconfigs" \
    CONFIG_DIRS="/config/backups /config/gamefiles /config/saves /config/gameconfigs" \
    GAME_RUN_SCRIPT="/opt/game/run.sh" \
    GAME_UPDATE_HOOK="/opt/game/update-hook.sh" \
    GAME_BACKUP_HOOK="/opt/game/backup-hook.sh" \
    STARTED_BUILD_FILE="/tmp/game-buildid" \
    INIT_LOCK="/tmp/init.lock" \
    SERVER_NAME="ServerByMe" \
    SERVER_PORT=9999

RUN set -x \
    && rm /etc/apt/sources.list.d/debian.sources \
    && echo "deb http://deb.debian.org/debian/ testing main contrib non-free non-free-firmware" > /etc/apt/sources.list \
    && apt update \
    && apt install -y ca-certificates apt-transport-https --no-install-recommends \
    && echo "" > /etc/apt/sources.list \
    && echo "Types: deb deb-src\nURIs: https://deb.debian.org/debian\nSuites: stable testing unstable\nComponents: main contrib non-free non-free-firmware\nEnabled: yes\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg" > /etc/apt/sources.list.d/debian.sources \
    && echo "Package: *\nPin: release a=testing\nPin-Priority: 510\n" > /etc/apt/preferences.d/list \
    && echo "Package: *\nPin: release a=unstable\nPin-Priority: 495\n" >> /etc/apt/preferences.d/list \
    && echo "Package: *\nPin: release a=stable\nPin-Priority: 490" >> /etc/apt/preferences.d/list \
    && apt update \
    && apt dist-upgrade -y \
    && apt autopurge -yy \
    && apt clean \
    && rm -rf /var/cache/* /var/lib/apt/lists/* /var/log/* /var/tmp/* /tmp/*

ARG CONTAINER_GID=10000
ARG CONTAINER_UID=10000

RUN set -x \
    && dpkg --add-architecture i386 \
    && apt update \
    && apt install -y nano curl jq pigz procps locales lib32gcc-s1 lib32stdc++6 --no-install-recommends \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && groupadd -g ${CONTAINER_GID} ${USER} \
    && useradd -u ${CONTAINER_UID} -g ${CONTAINER_GID} -m ${USER} \
    && mkdir -p /config /config/backups /config/gamefiles /config/saves /config/gameconfigs "${STEAMCMD_PATH}" \
    && chmod 777 /tmp \
    && chown -R "${CONTAINER_UID}":"${CONTAINER_GID}" /config "${STEAMCMD_PATH}" \
    && ln -s "${STEAMCMD_WORKING_PATH}/linux64/steamclient.so" "/usr/lib/x86_64-linux-gnu/steamclient.so" \
    && apt clean \
    && rm -rf /var/cache/* /var/lib/apt/lists/* /var/log/* /var/tmp/* /tmp/*

USER ${USER}

# Nothing is needed in HOME at runtime (it can be a tmpfs): init.sh copies steamcmd
# to STEAMCMD_WORKING_PATH and creates the ~/.steam/sdk32 and sdk64 links at startup
RUN curl -fsSL 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' | tar xzf - -C "${STEAMCMD_PATH}" \
    && cd "${STEAMCMD_PATH}" \
    && "${STEAMCMD_PATH}/steamcmd.sh" +login anonymous +quit \
    && rm -rf "${HOME}/.steam" "${HOME}/Steam"

# Owned by root: the steam user can run them but not modify them
COPY --chmod=755 init.sh /init.sh
COPY --chmod=755 update-check.sh /usr/local/bin/update-check
COPY --chmod=755 backup.sh /usr/local/bin/backup
COPY --chmod=644 functions.sh /usr/local/lib/games-docker/functions.sh

WORKDIR /config

ENTRYPOINT [ "/init.sh" ]
