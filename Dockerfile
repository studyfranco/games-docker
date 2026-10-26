FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

ARG CONTAINER_USER=steam
ARG DEBIAN_FRONTEND=noninteractive

# STEAM_COMPAT_DATA_PATH: Wine prefix created by Proton at first start (C: drive, registry, AppData)
# UMU_ID=0: GE-Proton 11 umu mode, the server exe must be launched with a relative path
ENV GE_PROTON_VERSION="11-11"
ENV GE_PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_PROTON_VERSION}/GE-Proton${GE_PROTON_VERSION}-x86_64.tar.gz" \
    PROTON_PATH="/opt/proton" \
    GAME_PLATFORM="windows" \
    STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAMCMD_WORKING_PATH}" \
    STEAM_COMPAT_DATA_PATH="/config/compatdata" \
    UMU_ID="0" \
    WINEDEBUG="-all"
# The Wine prefix gets its own folder in /config, created by init.sh at start
ENV CONFIG_DIRS="${CONFIG_DIRS} ${STEAM_COMPAT_DATA_PATH}"
# PROTON_PREFIX_TEMPLATE: Proton prefix prepared in the game image by proton-build-prefix (winetricks, .NET),
# copied at first start by proton-prefix-init
ENV PROTON_PREFIX_TEMPLATE="/opt/proton-prefix"

USER root

# GE-Proton 11 umu mode disables lsteamclient, which the servers need for Steamworks
RUN set -x \
    && apt update \
    && apt install -y python3 winbind dbus procps libvulkan1 libfreetype6 libfreetype6:i386 --no-install-recommends \
    && rm -f /etc/machine-id \
    && dbus-uuidgen --ensure=/etc/machine-id \
    && mkdir -p "${PROTON_PATH}" \
    && curl -fsSL "${GE_PROTON_URL}" | tar xzf - -C "${PROTON_PATH}" --strip-components=1 \
    && sed -i 's/append_to_env_str(self.env, "WINEDLLOVERRIDES", "lsteamclient=d", ";")/pass/' "${PROTON_PATH}/proton" \
    && ! grep -q "lsteamclient=d" "${PROTON_PATH}/proton" \
    && apt clean \
    && rm -rf /var/cache/* /var/lib/apt/lists/* /var/log/* /var/tmp/* /tmp/* \
    && mkdir -p "${PROTON_PREFIX_TEMPLATE}" \
    && chown steam:steam "${PROTON_PREFIX_TEMPLATE}"

# Owned by root: the steam user can run them but not modify them
COPY --chmod=755 proton-build-prefix.sh /usr/local/bin/proton-build-prefix
COPY --chmod=755 proton-prefix-init.sh /usr/local/bin/proton-prefix-init

USER ${CONTAINER_USER}
