#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
GAMESAVEDDIR="${GAMEFILESDIR}/ConanSandbox/Saved"
GAMEMODSDIR="${GAMEFILESDIR}/ConanSandbox/Mods"
GAMECONFIG="/config/gameconfigs/Game.ini"
SERVERSETTINGSINI="/config/gameconfigs/ServerSettings.ini"
WORKSHOP_APP_ID=440900

shutdown_server () {
    pkill -INT -f '[C]onanSandboxServer-Linux-Shipping' || true
}

check_number SERVER_PORT 7777
check_number SERVER_QUERY_PORT 27015
check_number RCON_PORT 25575
check_number MAX_PLAYERS 40

## Backup at each start
backup --start

## Saved (game.db) in /config/saves, configs (Saved/Config/LinuxServer) in /config/gameconfigs, logs in /config/logs
link_dir "${GAMESAVEDDIR}" "/config/saves"
link_dir "/config/saves/Config/LinuxServer" "/config/gameconfigs"
link_dir "/config/saves/Logs" "/config/logs"

## Settings applied only when the configs are created, then the files are the reference
if [ ! -f "${GAMECONFIG}" ]; then
    log_info "Game.ini not present, creating it"
    if [[ -n "${RCON_PASSWORD}" ]]; then
        printf '[RconPlugin]\nRconEnabled=1\nRconPassword=%s\nRconPort=%s\n' "${RCON_PASSWORD}" "${RCON_PORT}" > "${GAMECONFIG}"
    else
        printf '[RconPlugin]\nRconEnabled=0\nRconPort=%s\n' "${RCON_PORT}" > "${GAMECONFIG}"
    fi
fi

if [ ! -f "${SERVERSETTINGSINI}" ]; then
    log_info "ServerSettings.ini not present, creating it"
    printf '[ServerSettings]\nAdminPassword=%s\n' "$(admin_password)" > "${SERVERSETTINGSINI}"
fi

## Mods of the Steam Workshop
mkdir -p "${GAMEMODSDIR}"
IFS=',' read -ra mods <<< "${MOD_IDS// /}"
if [ "${#mods[@]}" -gt 0 ]; then
    if [[ "${SKIP_UPDATE,,}" != "true" ]]; then
        log_info "Downloading the mods: ${MOD_IDS}"
        steamcmd_args=(+force_install_dir "${GAMEFILESDIR}" +login anonymous)
        for mod in "${mods[@]}"; do
            steamcmd_args+=(+workshop_download_item "${WORKSHOP_APP_ID}" "${mod}" validate)
        done
        flock /config/gamefiles/.update.lock "${STEAMCMD_WORKING_PATH}/steamcmd.sh" "${steamcmd_args[@]}" +quit
    fi

    : > "${GAMEMODSDIR}/modlist.txt"
    for mod in "${mods[@]}"; do
        mkdir -p "${GAMEMODSDIR}/${mod}"
        cp -a "${GAMEFILESDIR}/steamapps/workshop/content/${WORKSHOP_APP_ID}/${mod}/." "${GAMEMODSDIR}/${mod}/" 2>/dev/null \
            || log_warn "Mod ${mod} not downloaded"
        find "${GAMEMODSDIR}/${mod}" -name "*.pak" -printf "*${mod}\\\\%f\n" >> "${GAMEMODSDIR}/modlist.txt"
    done
else
    : > "${GAMEMODSDIR}/modlist.txt"
fi

## Launch arguments, applied at each start
args=(/Game/Maps/ConanSandbox/ConanSandbox -server -log -port="${SERVER_PORT}" -queryport="${SERVER_QUERY_PORT}"
    -MaxPlayers="${MAX_PLAYERS}" -ServerName="${SERVER_NAME}")

if [[ -n "${SERVER_PASSWORD}" ]]; then
    args+=(-ServerPassword="${SERVER_PASSWORD}")
fi

log_info "Starting Conan Exiles Enhanced Dedicated Server"

cd "${GAMEFILESDIR}" || exit 1
run_server ./ConanSandboxServer.sh "${args[@]}" "${EXTRA_ARGS_ARRAY[@]}"
