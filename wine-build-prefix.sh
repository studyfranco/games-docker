#!/bin/bash

# Prepare the Wine prefix of a game image (WINE_PREFIX_TEMPLATE), one step per Docker layer:
#   RUN wine-build-prefix prefix        create the prefix (done by the first step when missing)
#   RUN wine-build-prefix <verb>        winetricks verb (corefonts, vcrun2019, dotnet48, win10...)
# The prefix is copied to WINEPREFIX at the first start of the container by wine-prefix-init

set -e

export WINEPREFIX="${WINE_PREFIX_TEMPLATE}"
export WINEDEBUG="-all"

# Virtual display for the installers
export DISPLAY=:1
Xvfb :1 -screen 0 1024x768x16 > /dev/null 2>&1 &
xvfb_pid=$!
trap 'kill "${xvfb_pid}" 2>/dev/null; rm -rf "${HOME}/.cache" /tmp/.X1-lock 2>/dev/null; true' EXIT
sleep 2

echo "wine-build-prefix: $1 ($(wine --version))"

if [ ! -f "${WINEPREFIX}/system.reg" ]; then
    # Without Wine Mono: the .NET Framework can be installed by winetricks
    WINEDLLOVERRIDES="mscoree=d" wineboot --init
    wineserver -w
fi

if [[ "$1" != "prefix" ]]; then
    winetricks -q --force "$1"
    wineserver -w
fi

if [[ "$1" == dotnet* ]]; then
    test -f "${WINEPREFIX}/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/mscorlib.dll"
fi
