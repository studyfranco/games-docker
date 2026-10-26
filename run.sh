#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
GAMESAVEDDIR="${GAMEFILESDIR}/WS/Saved"

# SaveAndExit through the server console (EchoPort), SIGINT if the console is unreachable or too slow
shutdown_server () {
    if ( exec 3<>"/dev/tcp/127.0.0.1/${ECHO_PORT}" && printf 'SaveAndExit 1\r\n' >&3 && sleep 5 ) 2>/dev/null; then
        log_info "SaveAndExit sent to the server console"
        ( sleep 45; pkill -INT -f '[W]SServer-Linux-Shipping' || true ) &
    else
        log_warn "Server console unreachable, stopping the server with SIGINT"
        pkill -INT -f '[W]SServer-Linux-Shipping' || true
    fi
}

check_number SERVER_PORT 8777
check_number SERVER_QUERY_PORT 27015
check_number ECHO_PORT 18888
check_number MAX_PLAYERS 32
check_number SERVER_ID 1
check_number BACKUP_INTERVAL 900
check_number SAVE_INTERVAL 600

## Backup at each start
backup --start

## Configs, gameplay settings, worlds, accounts and logs in /config
link_dir "${GAMESAVEDDIR}/Config/LinuxServer" "/config/gameconfigs"
link_dir "${GAMESAVEDDIR}/GameplaySettings" "/config/gameplayconfig"
link_dir "${GAMESAVEDDIR}/Worlds" "/config/saves"
link_dir "${GAMESAVEDDIR}/Accounts" "/config/savesAccount"
link_dir "${GAMESAVEDDIR}/Logs" "/config/logs"

## Launch arguments, applied at each start
args=("${SERVER_LEVEL}" -server -SILENT -log -UTF8Output -forcepassthrough -online=Steam
    -serverid="${SERVER_ID}" -SteamServerName="${SERVER_NAME}" -Port="${SERVER_PORT}" -QueryPort="${SERVER_QUERY_PORT}"
    -EchoPort="${ECHO_PORT}" -"${GAME_MODE}" -MaxPlayers="${MAX_PLAYERS}" -backup="${BACKUP_INTERVAL}" -saving="${SAVE_INTERVAL}")

if [[ -n "${SERVER_PASSWORD}" ]]; then
    args+=(-PSW="${SERVER_PASSWORD}")
fi

if [[ -n "${SERVER_ADMIN_PASSWORD}" ]]; then
    args+=(-adminpsw="${SERVER_ADMIN_PASSWORD}")
else
    log_warn "SERVER_ADMIN_PASSWORD not set, no admin password"
fi

if [[ -n "${RCON_PORT}" ]] && [[ -n "${RCON_PASSWORD}" ]]; then
    args+=(-rconpsw="${RCON_PASSWORD}" -rconport="${RCON_PORT}")
fi

# Cluster: the main server listens on MAIN_SERVER_PORT, the other servers connect to TO_MAIN_SERVER
if [[ -n "${MAIN_SERVER_PORT}" ]]; then
    args+=(-mainserverport="${MAIN_SERVER_PORT}")
fi

if [[ -n "${TO_MAIN_SERVER}" ]]; then
    args+=(-clientserverconnect="${TO_MAIN_SERVER}")
fi

# Mods of the Steam Workshop, downloaded by the server
if [[ -n "${MOD_IDS}" ]]; then
    log_info "Adding mods with ID list: ${MOD_IDS}"
    args+=(-mod="${MOD_IDS}")
fi

log_info "Starting Soulmask Dedicated Server"

cd "${GAMEFILESDIR}" || exit 1
run_server ./WSServer.sh "${args[@]}" "${EXTRA_ARGS_ARRAY[@]}"
