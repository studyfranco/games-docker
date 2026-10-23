#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
GAMESAVEDDIR="${GAMEFILESDIR}/FrozenFlame/Saved"
GAMECONFIG="/config/gameconfigs/Game.ini"

# Set a key of a section of Game.ini (the whole line is replaced, comment included)
set_game_ini () {
    sed -i "/^\[$(printf '%s' "$1" | sed 's/[][\/.*^$]/\\&/g')\]/,/^\[/ s/^$2=.*/$2=$(sed_escape "$3")/" "${GAMECONFIG}"
}

shutdown_server () {
    pkill -INT -f '[F]rozenFlameServer-' || true
}

check_number SERVER_PORT 7779
check_number SERVER_QUERY_PORT 7780
check_number RCON_PORT 27017
check_number MAX_PLAYERS 10
check_number DAY_DURATION 3600

## Backup at each start
backup --start

## Configs, saves and logs in /config
link_dir "${GAMESAVEDDIR}/Config/LinuxServer" "/config/gameconfigs"
link_dir "${GAMESAVEDDIR}/SaveGames" "/config/saves"
link_dir "${GAMESAVEDDIR}/Logs" "/config/logs"

## Settings applied only when the config is created, then the file is the reference
if [ ! -f "${GAMECONFIG}" ]; then
    log_info "Game.ini not present, downloading the official example"
    curl -fsSL "${GAME_CONFIG_URL}" -o "${GAMECONFIG}"

    set_game_ini "/Script/Engine.GameSession" "MaxPlayers" "${MAX_PLAYERS}"
    set_game_ini "/Script/FrozenFlame.FGameSession" "ServerPassword" "\"${SERVER_PASSWORD}\""
    if [[ "${FREE_PVP,,}" == "false" ]]; then
        set_game_ini "/Script/FrozenFlame.GameBalance" "bFreePVP" "False; Enable PVP for non-friends"
    fi
    set_game_ini "/Script/FrozenFlame.GameBalance" "DurationOfDay" "${DAY_DURATION}; How long a day lasts"
fi

## Launch arguments, applied at each start
args=(-log -MetaGameServerName="${SERVER_NAME}" -Port="${SERVER_PORT}" -queryPort="${SERVER_QUERY_PORT}")

# The admin commands are RCON commands, with the admin password
if [[ -n "${SERVER_ADMIN_PASSWORD}" ]]; then
    args+=(-RconPassword="${SERVER_ADMIN_PASSWORD}" -RconPort="${RCON_PORT}")
else
    log_warn "SERVER_ADMIN_PASSWORD not set, RCON (admin commands) disabled"
fi

log_info "Starting Frozen Flame Dedicated Server"

cd "${GAMEFILESDIR}" || exit 1
run_server ./FrozenFlameServer.sh "${args[@]}" "${EXTRA_ARGS_ARRAY[@]}"
