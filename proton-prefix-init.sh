#!/bin/bash

# Copy the Proton prefix prepared in the image (PROTON_PREFIX_TEMPLATE, proton-build-prefix) to STEAM_COMPAT_DATA_PATH:
# at the first start, and again when the Proton version changes (Proton would update the prefix and could
# replace the libraries installed in it). Without a prepared prefix, Proton creates its own one.

set -e

. /usr/local/lib/games-docker/functions.sh

if [ ! -f "${PROTON_PREFIX_TEMPLATE}/version" ]; then
    exit 0
fi

if [ -f "${STEAM_COMPAT_DATA_PATH}/version" ] && cmp -s "${STEAM_COMPAT_DATA_PATH}/version" "${PROTON_PREFIX_TEMPLATE}/version"; then
    exit 0
fi

log_info "Copying the Proton prefix of the image to ${STEAM_COMPAT_DATA_PATH}"
find "${STEAM_COMPAT_DATA_PATH}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "${PROTON_PREFIX_TEMPLATE}/." "${STEAM_COMPAT_DATA_PATH}/"
