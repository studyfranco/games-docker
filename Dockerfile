FROM ghcr.io/studyfranco/games-docker:proton

LABEL maintainer="studyfranco@gmail.com"

ARG CONTAINER_USER=steam
ARG DEBIAN_FRONTEND=noninteractive

USER root

# Tools of proton-build-prefix: the game images can add other winetricks verbs to the prefix
RUN set -x \
    && apt update \
    && apt install -y winetricks cabextract xvfb xauth --no-install-recommends \
    && apt clean \
    && rm -rf /var/cache/* /var/lib/apt/lists/* /var/log/* /var/tmp/* /tmp/*

USER ${CONTAINER_USER}

# Proton prefix with the core fonts, no sound and the .NET Framework 4.8 (Proton already has the Visual C++
# runtime), copied to /config/compatdata at the first start by proton-prefix-init (to call in the run.sh of the game)
RUN proton-build-prefix prefix
RUN proton-build-prefix corefonts
RUN proton-build-prefix sound=disabled
RUN proton-build-prefix dotnet48
