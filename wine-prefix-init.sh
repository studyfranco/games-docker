#!/bin/bash

# Create the Wine prefix of the game (WINEPREFIX) when missing:
# a copy of the prefix prepared in the image (WINE_PREFIX_TEMPLATE, wine-build-prefix), or a new Windows 10 prefix

set -e

. /usr/local/lib/games-docker/functions.sh

if [ -f "${WINEPREFIX}/system.reg" ]; then
    exit 0
fi

mkdir -p "${WINEPREFIX}"

if [ -f "${WINE_PREFIX_TEMPLATE}/system.reg" ]; then
    log_info "Creating the Wine prefix ${WINEPREFIX} from ${WINE_PREFIX_TEMPLATE}"
    cp -a "${WINE_PREFIX_TEMPLATE}/." "${WINEPREFIX}/"
else
    log_info "Creating the Wine prefix ${WINEPREFIX}"
    winecfg -v win10 > /dev/null 2>&1
    wineboot --init > /dev/null 2>&1
fi

wineserver -w || true
log_info "Wine prefix ready ($(wine --version))"
