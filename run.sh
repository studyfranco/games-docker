#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
GAMECONFIG="/config/gameconfigs/PalWorldSettings.ini"

# Set a quoted option of OptionSettings=(...) in PalWorldSettings.ini
set_option_str () {
    sed -i "s/$1=\"[^\"]*\"/$1=\"$(sed_escape "$2")\"/" "${GAMECONFIG}"
}

# Set an unquoted option (number, boolean) of OptionSettings=(...) in PalWorldSettings.ini
set_option () {
    sed -i "s/$1=[^,)]*/$1=$2/" "${GAMECONFIG}"
}

shutdown_server () {
    pkill -INT -f '[P]alServer-Linux-Shipping' || true
}

check_number SERVER_PORT 8211
check_number SERVER_QUERY_PORT 27015
check_number RCON_PORT 25575
check_number REST_API_PORT 8212
check_number MAX_PLAYERS 32
check_number MAX_PLAYERS_COOP 32
check_number MAX_PLAYERS_GUILD 32

## Backup at each start
backup --start

## Configs, saves and logs in /config
link_dir "${GAMEFILESDIR}/Pal/Saved/Config/LinuxServer" "/config/gameconfigs"
link_dir "${GAMEFILESDIR}/Pal/Saved/SaveGames" "/config/saves"
link_dir "${GAMEFILESDIR}/Pal/Saved/Logs" "/config/logs"

## Settings applied only when the config is created, then the file is the reference
if [ ! -f "${GAMECONFIG}" ]; then
    log_info "Server config not present, creating it from the default one"
    cp "${GAMEFILESDIR}/DefaultPalWorldSettings.ini" "${GAMECONFIG}"

    set_option_str "ServerName" "${SERVER_NAME}"
    set_option_str "ServerPassword" "${SERVER_PASSWORD}"
    set_option_str "AdminPassword" "$(admin_password)"
    set_option "ServerPlayerMaxNum" "${MAX_PLAYERS}"
    set_option "CoopPlayerMaxNum" "${MAX_PLAYERS_COOP}"
    set_option "GuildPlayerMaxNum" "${MAX_PLAYERS_GUILD}"
    set_option "PublicPort" "${SERVER_PORT}"
    set_option "RCONEnabled" "True"
    set_option "RCONPort" "${RCON_PORT}"
    # REST API used by the update and backup hooks (in game messages, save), not published by the container
    set_option "RESTAPIEnabled" "True"
    set_option "RESTAPIPort" "${REST_API_PORT}"
fi

log_info "Starting Palworld Dedicated Server"

# -EpicApp=PalServer: needed for the crossplay
cd "${GAMEFILESDIR}" || exit 1
run_server ./PalServer.sh -log -port="${SERVER_PORT}" -publicport="${SERVER_PORT}" -queryport="${SERVER_QUERY_PORT}" -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS -EpicApp=PalServer "${EXTRA_ARGS_ARRAY[@]}"
