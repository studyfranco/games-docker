#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"

check_number SERVER_PORT 2456
check_number SAVE_INTERVAL 1800

if [[ "${PUBLIC}" != "0" ]]; then
    PUBLIC=1
fi

if [ "${#SERVER_PASSWORD}" -lt 5 ]; then
    log_warn "SERVER_PASSWORD must have at least 5 characters: Valheim refuses to start otherwise"
    exit 1
fi

## Backup at each start
backup --start

## Admin, banned and permitted lists in /config/gameconfigs (Valheim reads them in the save folder)
for list in adminlist bannedlist permittedlist; do
    touch "/config/gameconfigs/${list}.txt"
    link_file "/config/saves/${list}.txt" "/config/gameconfigs/${list}.txt"
done

## Launch arguments, applied at each start
args=(-nographics -batchmode -name "${SERVER_NAME}" -port "${SERVER_PORT}" -world "${WORLD_NAME}"
    -password "${SERVER_PASSWORD}" -public "${PUBLIC}" -savedir /config/saves -saveinterval "${SAVE_INTERVAL}")

if [[ "${CROSSPLAY,,}" == "true" ]]; then
    args+=(-crossplay)
fi

if [[ -n "${PRESET}" ]]; then
    args+=(-preset "${PRESET}")
fi

# MODIFIERS="combat=hard,raids=none"
IFS=',' read -ra modifiers <<< "${MODIFIERS}"
for modifier in "${modifiers[@]}"; do
    if [[ "${modifier}" == *=* ]]; then
        args+=(-modifier "${modifier%%=*}" "${modifier#*=}")
    fi
done

# SET_KEYS="nobuildcost,playerevents"
IFS=',' read -ra setkeys <<< "${SET_KEYS}"
for setkey in "${setkeys[@]}"; do
    if [[ -n "${setkey}" ]]; then
        args+=(-setkey "${setkey}")
    fi
done

cd "${GAMEFILESDIR}" || exit 1

export SteamAppId=892970
export LD_LIBRARY_PATH="${GAMEFILESDIR}/linux64:${LD_LIBRARY_PATH}"

## BepInEx installed by hand in the game files: the server is started with it
if [ -f "${GAMEFILESDIR}/BepInEx/core/BepInEx.Preloader.dll" ]; then
    log_info "BepInEx found, starting the server with the mods"
    if [ -f "${GAMEFILESDIR}/doorstop_libs/libdoorstop_x64.so" ]; then
        # Doorstop 4 and above
        export DOORSTOP_ENABLED=1
        export DOORSTOP_TARGET_ASSEMBLY="${GAMEFILESDIR}/BepInEx/core/BepInEx.Preloader.dll"
        export LD_LIBRARY_PATH="${GAMEFILESDIR}/doorstop_libs:${LD_LIBRARY_PATH}"
        export LD_PRELOAD="${GAMEFILESDIR}/doorstop_libs/libdoorstop_x64.so:${LD_PRELOAD}"
    else
        # Older Doorstop versions
        export DOORSTOP_ENABLE=TRUE
        export DOORSTOP_INVOKE_DLL_PATH="${GAMEFILESDIR}/BepInEx/core/BepInEx.Preloader.dll"
        export DOORSTOP_CORLIB_OVERRIDE_PATH="${GAMEFILESDIR}/unstripped_corlib"
        export LD_LIBRARY_PATH="${GAMEFILESDIR}/doorstop_libs:${LD_LIBRARY_PATH}"
        export LD_PRELOAD="${GAMEFILESDIR}/libdoorstop_x64.so:${LD_PRELOAD}"
    fi
fi

log_info "Starting Valheim Dedicated Server"

run_server ./valheim_server.x86_64 "${args[@]}" "${EXTRA_ARGS_ARRAY[@]}"
