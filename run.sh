#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
# -UserDir of the server (Wine path of /config/gamefiles/Icarus), Saved/ is created in it
GAMESAVEDDIR="${GAMEFILESDIR}/Icarus/Saved"
GAMEUSERDIR_WINE='Z:\config\gamefiles\Icarus'
ENGINEINI="/config/gameconfigs/Engine.ini"
SERVERSETTINGSINI="/config/gameconfigs/ServerSettings.ini"

shutdown_server () {
    pkill -INT -f '[I]carusServer-Win64-Shipping.exe' || true
}

check_number SERVER_PORT 17777
check_number SERVER_QUERY_PORT 27015
check_number MAX_PLAYERS 8 1 8
check_number STEAM_ASYNC_TIMEOUT 60

## Backup at each start
backup --start

## Configs in /config/gameconfigs, prospects in /config/saves, logs in /config/logs
link_dir "${GAMESAVEDDIR}/Config/WindowsServer" "/config/gameconfigs"
link_dir "${GAMESAVEDDIR}/PlayerData/DedicatedServer/Prospects" "/config/saves"
link_dir "${GAMESAVEDDIR}/Logs" "/config/logs"

## Settings applied only when the configs are created, then the files are the reference
if [ ! -f "${ENGINEINI}" ]; then
    log_info "Engine.ini not present, creating it"
    # Steam async timeout (slow systems and connections)
    printf '[OnlineSubsystemSteam]\nAsyncTaskTimeout=%s\n' "${STEAM_ASYNC_TIMEOUT}" > "${ENGINEINI}"
fi

if [ ! -f "${SERVERSETTINGSINI}" ]; then
    log_info "ServerSettings.ini not present, creating it"
    {
        echo '[/Script/Icarus.DedicatedServerSettings]'
        echo "SessionName=${SERVER_NAME}"
        echo "JoinPassword=${SERVER_PASSWORD}"
        echo "MaxPlayers=${MAX_PLAYERS}"
        echo "AdminPassword=$(admin_password)"
        echo "ShutdownIfNotJoinedFor=${SHUTDOWN_NOT_JOINED_FOR}"
        echo "ShutdownIfEmptyFor=${SHUTDOWN_EMPTY_FOR}"
        echo "AllowNonAdminsToLaunchProspects=${ALLOW_NON_ADMINS_LAUNCH}"
        echo "AllowNonAdminsToDeleteProspects=${ALLOW_NON_ADMINS_DELETE}"
        echo "LoadProspect=${LOAD_PROSPECT}"
        echo "CreateProspect=${CREATE_PROSPECT}"
        echo "ResumeProspect=${RESUME_PROSPECT}"
    } > "${SERVERSETTINGSINI}"
fi

## Server log to the container output
start_log_tail "${GAMESAVEDDIR}/Logs/Icarus.log"

log_info "Starting Icarus Dedicated Server"

# Relative exe path so Proton launches it directly; with an absolute path it goes
# through umu.exe, which blocks the server at startup once lsteamclient is enabled.
cd "${GAMEFILESDIR}/Icarus/Binaries/Win64" || exit 1
run_server "${PROTON_PATH}/proton" run IcarusServer-Win64-Shipping.exe -Log -UserDir="${GAMEUSERDIR_WINE}" -SteamServerName="${SERVER_NAME}" -PORT="${SERVER_PORT}" -QueryPort="${SERVER_QUERY_PORT}" "${EXTRA_ARGS_ARRAY[@]}"
