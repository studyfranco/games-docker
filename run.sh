#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"
# Instance folder of the server (-path): config, Saves/, Storage/ and logs
INSTANCEDIR="/config/saves"
INSTANCEDIR_WINE='Z:\config\saves'

shutdown_server () {
    pkill -INT -f '[S]paceEngineersDedicated.exe' || true
}

## Backup at each start
backup --start

## The config and the world are created with the Space Engineers Dedicated Server tool (Windows)
if [ ! -f "${GAMECONFIG}" ] && { [ ! -f "${INSTANCEDIR}/SpaceEngineers-Dedicated.cfg" ] || [ -L "${INSTANCEDIR}/SpaceEngineers-Dedicated.cfg" ]; }; then
    log_warn "${GAMECONFIG} not present: copy the SpaceEngineers-Dedicated.cfg of your instance there, and its world in ${INSTANCEDIR}/Saves"
    exit 1
fi
link_file "${INSTANCEDIR}/SpaceEngineers-Dedicated.cfg" "${GAMECONFIG}"

## World to load: WORLD_NAME, else the one of the config, else the first world in Saves
world="${WORLD_NAME}"
if [[ -z "${world}" ]]; then
    world=$(sed -n 's:.*<LoadWorld>\(.*\)</LoadWorld>.*:\1:p' "${GAMECONFIG}" | tr '\\' '/' | sed 's:/Sandbox.sbc$::; s:/*$::')
    world="${world##*/}"
fi
if [[ -z "${world}" ]] || [ ! -f "${INSTANCEDIR}/Saves/${world}/Sandbox.sbc" ]; then
    world=$(find "${INSTANCEDIR}/Saves" -mindepth 2 -maxdepth 2 -name Sandbox.sbc -printf '%h\n' 2>/dev/null | head -n 1)
    world="${world##*/}"
fi
if [[ -z "${world}" ]]; then
    log_warn "No world in ${INSTANCEDIR}/Saves (<world>/Sandbox.sbc): copy the world of your instance there"
    exit 1
fi
log_info "World: ${world}"

## Paths and IP of the container, adapted at each start (the other settings of the config are the reference)
sed -i -E "s#<LoadWorld>.*</LoadWorld>|<LoadWorld />#<LoadWorld>${INSTANCEDIR_WINE//\\/\\\\}\\\\Saves\\\\$(sed_escape "${world}")\\\\Sandbox.sbc</LoadWorld>#" "${GAMECONFIG}"
sed -i -E "s#<IP>.*</IP>#<IP>0.0.0.0</IP>#" "${GAMECONFIG}"

## Proton prefix with .NET Framework 4.8 (first start, and when the Proton version changes: copy of the prefix of the image)
proton-prefix-init

## Server log to the container output (a new log file at each start)
rm -f "${INSTANCEDIR}"/*.log
(
    for _ in $(seq 1 120); do
        log=$(ls -1t "${INSTANCEDIR}"/*.log 2>/dev/null | head -n 1)
        if [[ -n "${log}" ]]; then
            exec tail -F -n +1 "${log}"
        fi
        sleep 5
    done
) &
LOG_TAIL_PID=$!

log_info "Starting Space Engineers Dedicated Server"

# Relative exe path so Proton launches it directly; with an absolute path it goes
# through umu.exe, which blocks the server at startup once lsteamclient is enabled.
cd "${GAMEFILESDIR}/DedicatedServer64" || exit 1
run_server "${PROTON_PATH}/proton" run SpaceEngineersDedicated.exe -noconsole -ignorelastsession -path "${INSTANCEDIR_WINE}" "${EXTRA_ARGS_ARRAY[@]}"
