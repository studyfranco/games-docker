#!/bin/bash
 
set -e

. /usr/local/lib/games-docker/functions.sh

echo "
System info:
OS:  $(uname -a)
CPU: $(lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//g')
RAM: $(awk '/MemAvailable/ {printf( "%d\n", $2 / 1024000 )}' /proc/meminfo)GB/$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024000 )}' /proc/meminfo)GB
HDD: $(df -BG /config/gamefiles | awk 'NR==2 {printf "%dGB/%dGB (%s used) for /config/gamefiles\n", $3, $2, $5}')"

printf "\\nCurrent user:\\n"
id

ramAvailable=$(awk '/MemAvailable/ {printf( "%d\n", $2 / 1024000 )}' /proc/meminfo)
printf "Checking available memory...%sGB detected\\n" "${ramAvailable}"

if [[ "$ramAvailable" -lt 2 ]]; then
    printf "You have less than the required 2GB minmum (%sGB detected) of available RAM to run the game server.\\nIt is likely that the server will fail to load properly.\\n" "${ramAvailable}"
fi

# Every folder of CONFIG_DIRS (can be extended by the images built on this one) must be writable:
# mount the whole /config, or one volume per folder
notWritable=""
for dir in ${CONFIG_DIRS}; do
    if mkdir -p "${dir}" 2>/dev/null && touch "${dir}/.permtest" 2>/dev/null; then
        rm -f "${dir}/.permtest"
    else
        notWritable="${notWritable} ${dir}"
    fi
done

if [[ -n "${notWritable}" ]]; then
    printf "Not writable by the current user (%s):%s\\n" "$(id -u):$(id -g)" "${notWritable}"
    printf "Mount them (or the whole /config) and change the owner of the mounted folders on the host, e.g. chown -R %s:%s /path/to/config\\n" "$(id -u)" "$(id -g)"
    exit 1
fi

# update-check does nothing while the server is starting
touch "${INIT_LOCK}"

# steamcmd working copy in HOME (tmpfs), copied only when missing
if [ ! -d "${STEAMCMD_WORKING_PATH}" ]; then
    cp -r "${STEAMCMD_PATH}" "${STEAMCMD_WORKING_PATH}"
fi

"${STEAMCMD_WORKING_PATH}/steamcmd.sh" +login anonymous +quit

mkdir -p "${STEAM_SDK32_PATH}" "${STEAM_SDK64_PATH}"
ln -sfn "${STEAMCMD_WORKING_PATH}/linux32/steamclient.so" "${STEAM_SDK32_PATH}/steamclient.so"
ln -sfn "${STEAMCMD_WORKING_PATH}/linux64/steamclient.so" "${STEAM_SDK64_PATH}/steamclient.so"
ln -sfn "${STEAMCMD_WORKING_PATH}/linux32/steamclient.so" "${STEAM_SDK32_PATH}/steamservice.so"
ln -sfn "${STEAMCMD_WORKING_PATH}/linux64/steamclient.so" "${STEAM_SDK64_PATH}/steamservice.so"
ln -sfn "${STEAMCMD_WORKING_PATH}/linux32/steamclient.so" "${STEAMCMD_WORKING_PATH}/steamservice.so"
ln -sfn "${STEAMCMD_WORKING_PATH}/linux32/steamcmd" "${STEAMCMD_WORKING_PATH}/linux32/steam"
ln -sfn "${STEAMCMD_WORKING_PATH}/linux64/steamcmd" "${STEAMCMD_WORKING_PATH}/linux64/steam"
ln -sfn "${STEAMCMD_WORKING_PATH}/steamcmd.sh" "${STEAMCMD_WORKING_PATH}/steam.sh"

## Initialise and update game files
if [[ -z "${STEAM_APP_ID}" ]]; then
    printf "No STEAM_APP_ID given, skipping game installation\\n"
elif [[ "${SKIP_UPDATE,,}" == "true" ]]; then
    printf "Skipping update as flag is set\\n"
else
    space=$(stat -f --format="%a*%S" /config/gamefiles)
    space=$((space/1024/1024/1024))
    printf "Checking available space...%sGB detected\\n" "${space}"

    if [[ "$space" -lt 8 ]]; then
        printf "You have less than 8GB (%sGB detected) of available space to download the game.\\nIf this is a fresh install, it will probably fail.\\n" "${space}"
    fi

    steamcmd_args=()
    if [[ -n "${GAME_PLATFORM}" ]]; then
        # Force the platform of the downloaded depots (e.g. windows)
        steamcmd_args+=(+@sSteamCmdForcePlatformType "${GAME_PLATFORM}")
    fi
    # +force_install_dir must come before +login
    steamcmd_args+=(+force_install_dir /config/gamefiles +login anonymous +app_update "${STEAM_APP_ID}")
    if [[ -n "${GAME_BRANCH}" ]]; then
        # Steam beta branch of the server (e.g. public, experimental)
        steamcmd_args+=(-beta "${GAME_BRANCH}")
    fi
    steamcmd_args+=(validate +quit)

    manifest="/config/gamefiles/steamapps/appmanifest_${STEAM_APP_ID}.acf"
    installed="false"
    [ -f "${manifest}" ] && installed="true"

    printf "Downloading the latest version of the game...\\n"
    # Lock for the game files shared by several containers (one update at a time)
    if ! flock /config/gamefiles/.update.lock "${STEAMCMD_WORKING_PATH}/steamcmd.sh" "${steamcmd_args[@]}"; then
        if [[ "${installed}" == "true" ]]; then
            # Steam can refuse the manifest of the installed build to anonymous logins:
            # without the app manifest, steamcmd checks the files and downloads only what changed
            log_warn "Update failed, trying again without the app manifest of the installed build"
            mv -f "${manifest}" "${manifest}.old"
            if ! flock /config/gamefiles/.update.lock "${STEAMCMD_WORKING_PATH}/steamcmd.sh" "${steamcmd_args[@]}"; then
                [ -f "${manifest}" ] || mv -f "${manifest}.old" "${manifest}"
                log_warn "Update failed again, starting the installed version of the game"
            fi
        else
            printf "Download of the game failed\\n"
            exit 1
        fi
    fi
fi

# Build of the game at start, used by update-check when the game files are shared
manifest="/config/gamefiles/steamapps/appmanifest_${STEAM_APP_ID}.acf"
if [[ -n "${STEAM_APP_ID}" ]] && [ -f "${manifest}" ]; then
    awk '$1 == "\"buildid\"" { gsub(/"/, "", $2); print $2; exit }' "${manifest}" > "${STARTED_BUILD_FILE}"
fi

## Game specific part: the start script of the game image
rm -f "${INIT_LOCK}"

if [[ $# -gt 0 ]]; then
    exec "$@"
fi

if [[ ! -x "${GAME_RUN_SCRIPT}" ]]; then
    printf "No game start script found (%s), nothing to run\\n" "${GAME_RUN_SCRIPT}"
    exit 0
fi

exec "${GAME_RUN_SCRIPT}"
