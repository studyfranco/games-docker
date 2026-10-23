#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
GAMESAVEDDIR="${GAMEFILESDIR}/FactoryGame/Saved"

shutdown_server () {
    pkill -INT -f '[F]actoryServer-Linux-Shipping' || true
}

check_number SERVER_PORT 7777
check_number SERVER_MESSAGING_PORT 8888
check_number MAX_PLAYERS 4
check_number AUTOSAVE_NUM 5
check_number MAX_OBJECTS 2162688
check_number MAX_TICK_RATE 30
check_number TIMEOUT 30

[[ "${SERVER_STREAMING,,}" == "true" ]] && SERVER_STREAMING="1" || SERVER_STREAMING="0"

## Backup at each start
backup --start

## Configs, saves (in HOME, tmpfs) and logs in /config
link_dir "${GAMESAVEDDIR}/Config/LinuxServer" "/config/gameconfigs"
link_dir "${HOME}/.config/Epic/FactoryGame/Saved/SaveGames" "/config/saves"
link_dir "${GAMESAVEDDIR}/Logs" "/config/logs"

## Launch arguments, applied at each start
args=(-Port="${SERVER_PORT}" -ReliablePort="${SERVER_MESSAGING_PORT}" -ExternalReliablePort="${SERVER_MESSAGING_PORT}"
    "-ini:Engine:[/Script/FactoryGame.FGSaveSession]:mNumRotatingAutosaves=${AUTOSAVE_NUM}"
    "-ini:Engine:[/Script/Engine.GarbageCollectionSettings]:gc.MaxObjectsInEditor=${MAX_OBJECTS}"
    "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:LanServerMaxTickRate=${MAX_TICK_RATE}"
    "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:NetServerMaxTickRate=${MAX_TICK_RATE}"
    "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:ConnectionTimeout=${TIMEOUT}"
    "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:InitialConnectTimeout=${TIMEOUT}"
    "-ini:Engine:[ConsoleVariables]:wp.Runtime.EnableServerStreaming=${SERVER_STREAMING}"
    "-ini:Game:[/Script/Engine.GameSession]:ConnectionTimeout=${TIMEOUT}"
    "-ini:Game:[/Script/Engine.GameSession]:InitialConnectTimeout=${TIMEOUT}"
    "-ini:Game:[/Script/Engine.GameSession]:MaxPlayers=${MAX_PLAYERS}"
    "-ini:GameUserSettings:[/Script/Engine.GameSession]:MaxPlayers=${MAX_PLAYERS}")

if [[ "${DISABLE_SEASONAL_EVENTS,,}" == "true" ]]; then
    args+=(-DisableSeasonalEvents)
fi

if [[ -n "${MULTIHOME}" ]]; then
    args+=(-multihome="${MULTIHOME}")
fi

log_info "Starting Satisfactory Dedicated Server"

cd "${GAMEFILESDIR}" || exit 1
run_server ./FactoryServer.sh "${args[@]}" "${EXTRA_ARGS_ARRAY[@]}"
