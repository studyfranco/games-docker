#!/bin/bash

# Run from the host cron: docker exec <container> update-check
# If a new build of the game is available on Steam, warn the players (game hook) and stop the
# server gracefully: Docker restarts the container (restart: unless-stopped) and init.sh updates the game.
# When the game files are shared with another container which updated them, the server is restarted too.
# Options:
#   --check   only check, exit 10 when an update is available

set -e

# Also log in the container output (docker logs)
exec > >(tee -a /proc/1/fd/1) 2>&1

. /usr/local/lib/games-docker/functions.sh

if [[ -z "${STEAM_APP_ID}" ]]; then
    echo "$(timestamp) UPDATE: No STEAM_APP_ID, nothing to check"
    exit 0
fi

if [ -e "${INIT_LOCK}" ]; then
    echo "$(timestamp) UPDATE: The server is starting (init.sh), skipping the check"
    exit 0
fi

manifest="/config/gamefiles/steamapps/appmanifest_${STEAM_APP_ID}.acf"
if [ ! -f "${manifest}" ]; then
    echo "$(timestamp) UPDATE: ${manifest} not found, the game is not installed"
    exit 0
fi

branch="${GAME_BRANCH:-public}"
installed=$(awk '$1 == "\"buildid\"" { gsub(/"/, "", $2); print $2; exit }' "${manifest}")
started=$(cat "${STARTED_BUILD_FILE}" 2>/dev/null || true)

restart_needed () {
    echo "$(timestamp) UPDATE: $1"

    if [[ "${CHECK_ONLY}" == "true" ]]; then
        exit 10
    fi

    # Game specific part: warn the players in game, save...
    if [ -x "${GAME_UPDATE_HOOK}" ]; then
        "${GAME_UPDATE_HOOK}" || echo "$(timestamp) UPDATE: WARN, the game update hook failed"
    fi

    echo "$(timestamp) UPDATE: Restarting the server"
    kill -TERM 1
    exit 0
}

[[ "$1" == "--check" ]] && CHECK_ONLY="true"

# Game files shared with another container which updated them
if [[ -n "${started}" ]] && [[ "${installed}" != "${started}" ]]; then
    restart_needed "The game files were updated by another container: build ${started} -> ${installed}"
fi

if [[ "${SKIP_UPDATE,,}" == "true" ]]; then
    echo "$(timestamp) UPDATE: SKIP_UPDATE is set, the update would not be installed at restart"
    exit 0
fi

# steamcmd working copy in HOME (tmpfs), copied only when missing
if [ ! -d "${STEAMCMD_WORKING_PATH}" ]; then
    cp -r "${STEAMCMD_PATH}" "${STEAMCMD_WORKING_PATH}"
fi

# Drop the cached app info, steamcmd can return an old build otherwise
rm -rf "${STEAMCMD_WORKING_PATH}/appcache"
latest=$("${STEAMCMD_WORKING_PATH}/steamcmd.sh" +login anonymous +app_info_update 1 +app_info_print "${STEAM_APP_ID}" +quit 2>/dev/null \
    | awk -v branch="\"${branch}\"" '
        $1 == "\"branches\"" { in_branches = 1; next }
        in_branches && $1 == branch { in_branch = 1; next }
        in_branch && $1 == "\"buildid\"" { gsub(/"/, "", $2); print $2; exit }
    ')

if [[ -z "${latest}" ]]; then
    echo "$(timestamp) UPDATE: ERROR, unable to get the latest build of ${STEAM_APP_ID} (branch ${branch}) from Steam"
    exit 1
fi

if [[ "${installed}" == "${latest}" ]]; then
    echo "$(timestamp) UPDATE: Server up to date (build ${installed})"
    exit 0
fi

restart_needed "New build available: ${installed} -> ${latest} (branch ${branch})"
