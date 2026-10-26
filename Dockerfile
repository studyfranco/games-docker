FROM ghcr.io/studyfranco/games-docker:master

LABEL maintainer="studyfranco@gmail.com"

ARG CONTAINER_USER=steam
ARG DEBIAN_FRONTEND=noninteractive

# WINEPREFIX: Wine prefix of the game, created at first start by wine-prefix-init (C: drive, registry, AppData)
# WINE_PREFIX_TEMPLATE: prefix prepared in the game image by wine-build-prefix (winetricks), copied at first start
ENV GAME_PLATFORM="windows" \
    WINEPREFIX="/config/compatdata/pfx" \
    WINEARCH="win64" \
    WINEDEBUG="-all" \
    WINE_PREFIX_TEMPLATE="/opt/wine-prefix"
# The Wine prefix gets its own folder in /config, created by init.sh at start
ENV CONFIG_DIRS="${CONFIG_DIRS} /config/compatdata"

USER root

# Wine of WineHQ (classic WoW64, like most of the Wine game server images), winbind (NTLM),
# Xvfb (virtual display), winetricks and cabextract (Windows runtimes in the prefix).
# libgd3 and libavif16 of stable: in testing, their dependency libabsl has not the same version in amd64 and i386
RUN set -x \
    && mkdir -pm755 /etc/apt/keyrings \
    && curl -fsSL https://dl.winehq.org/wine-builds/winehq.key -o /etc/apt/keyrings/winehq-archive.key \
    && curl -fsSL https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources -o /etc/apt/sources.list.d/winehq-trixie.sources \
    && printf 'Package: libgd3 libgd3:i386 libavif16 libavif16:i386\nPin: release a=stable\nPin-Priority: 990\n' > /etc/apt/preferences.d/wine \
    && apt update \
    && apt install -y winehq-stable wine-stable:amd64 wine-stable-amd64 wine-stable-i386:i386 \
        winbind winetricks cabextract xvfb xauth --no-install-recommends \
    && apt clean \
    && rm -rf /var/cache/* /var/lib/apt/lists/* /var/log/* /var/tmp/* /tmp/* \
    && mkdir -p "${WINE_PREFIX_TEMPLATE}" \
    && chown steam:steam "${WINE_PREFIX_TEMPLATE}"

# Owned by root: the steam user can run them but not modify them
COPY --chmod=755 wine-prefix-init.sh /usr/local/bin/wine-prefix-init
COPY --chmod=755 wine-build-prefix.sh /usr/local/bin/wine-build-prefix

USER ${CONTAINER_USER}
