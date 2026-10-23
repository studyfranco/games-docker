#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
GAMESAVEDDIR="${GAMEFILESDIR}/BoatGame/Saved"
GAMEHOSTCONFIG="/config/gameconfigs/CustomHostUserSettings.ini"

shutdown_server () {
    pkill -INT -f '[B]oatGameServer-Win64-Shipping.exe' || true
}

check_number SERVER_PORT 7777
check_number SERVER_QUERY_PORT 27015
check_number MAX_PLAYERS 10 1 10
check_number SAVE_INTERVAL 300 10 900

## Backup at each start
backup --start

## Saves (PersistedData) in /config/saves, server settings (PersistedData/CustomConfig) in /config/gameconfigs, logs in /config/logs
link_dir "${GAMESAVEDDIR}/PersistedData" "/config/saves"
link_dir "/config/saves/CustomConfig" "/config/gameconfigs"
link_dir "${GAMESAVEDDIR}/Logs" "/config/logs"

## Settings applied once when the server created its config, then the file is the reference
if [ -f "${GAMEHOSTCONFIG}" ]; then
    if ! config_seeded "CustomHostUserSettings"; then
        log_info "Applying the environment variables to ${GAMEHOSTCONFIG} (only this time)"
        set_ini_key "${GAMEHOSTCONFIG}" "HostServerDisplayName" "${SERVER_NAME}"
        set_ini_key "${GAMEHOSTCONFIG}" "HostServerPassword" "${SERVER_PASSWORD}"
        set_ini_key "${GAMEHOSTCONFIG}" "MaxPlayers" "${MAX_PLAYERS}"
        set_ini_key "${GAMEHOSTCONFIG}" "AutosaveTimerSeconds" "${SAVE_INTERVAL}"
        mark_config_seeded "CustomHostUserSettings"
    fi
else
    log_warn "${GAMEHOSTCONFIG} not present, it will be created by the server: restart the container to apply the environment variables"
fi

## Server log to the container output
start_log_tail "${GAMESAVEDDIR}/Logs/BoatGame.log"

log_info "Starting Voyagers of Nera Dedicated Server"

# Relative exe path so Proton launches it directly; with an absolute path it goes
# through umu.exe, which blocks the server at startup once lsteamclient is enabled.
cd "${GAMEFILESDIR}/BoatGame/Binaries/Win64" || exit 1
run_server "${PROTON_PATH}/proton" run BoatGameServer-Win64-Shipping.exe -Port="${SERVER_PORT}" -QueryPort="${SERVER_QUERY_PORT}" -log -LoggingInShippingEnabled=true "${EXTRA_ARGS_ARRAY[@]}"
