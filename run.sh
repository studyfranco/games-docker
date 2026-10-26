#!/bin/bash

set -e

. /usr/local/lib/games-docker/functions.sh

GAMEFILESDIR="/config/gamefiles"

shutdown_server () {
    pkill -INT -f '[e]nshrouded_server.exe' || true
}

check_number SERVER_PORT 15637
check_number MAX_PLAYERS 16 1 16

## Backup at each start
backup --start

## Settings applied only when the config is created, then the file is the reference
if [ ! -f "${GAMECONFIG}" ] && { [ ! -f "${GAMEFILESDIR}/enshrouded_server.json" ] || [ -L "${GAMEFILESDIR}/enshrouded_server.json" ]; }; then
    log_info "Server config not present, creating it from the example"

    if [[ -z "${SERVER_PASSWORD}" ]]; then
        log_warn "SERVER_PASSWORD not set, the Friend group (players) has no password: the server is public"
    fi

    tmpfile=$(mktemp)
    jq \
      --arg name "${SERVER_NAME}" \
      --arg password "${SERVER_PASSWORD}" \
      --arg adminPassword "$(admin_password)" \
      --argjson port "${SERVER_PORT}" \
      --argjson slots "${MAX_PLAYERS}" \
      --arg voiceChatMode "${VOICE_CHAT_MODE}" \
      --arg voiceChat "${ENABLE_VOICE_CHAT,,}" \
      --arg textChat "${ENABLE_TEXT_CHAT,,}" \
      '
      .name = $name
      | .queryPort = $port
      | .slotCount = $slots
      | (.userGroups[] | select(.name == "Admin") | .password) = $adminPassword
      | (.userGroups[] | select(.name == "Friend") | .password) = $password
      | (if $voiceChatMode != "" then .voiceChatMode = $voiceChatMode else . end)
      | (if $voiceChat != "" then .enableVoiceChat = ($voiceChat == "true") else . end)
      | (if $textChat != "" then .enableTextChat = ($textChat == "true") else . end)
      ' /opt/game/enshrouded_server_example.json > "${tmpfile}"
    cat "${tmpfile}" > "${GAMECONFIG}"
    rm -f "${tmpfile}"
fi

## Config, saves and logs in /config
link_file "${GAMEFILESDIR}/enshrouded_server.json" "${GAMECONFIG}"
link_dir "${GAMEFILESDIR}/savegame" "/config/saves"
link_dir "${GAMEFILESDIR}/logs" "/config/logs"

if [[ "$(jq -r '.saveDirectory + " " + .logDirectory' "${GAMECONFIG}")" != "./savegame ./logs" ]]; then
    log_warn "saveDirectory and logDirectory of ${GAMECONFIG} must be ./savegame and ./logs to use /config/saves and /config/logs"
fi

## Server log to the container output
start_log_tail "${GAMEFILESDIR}/logs/enshrouded_server.log"

log_info "Starting Enshrouded Dedicated Server"

# Relative exe path so Proton launches it directly; with an absolute path it goes
# through umu.exe, which blocks the server at startup once lsteamclient is enabled.
cd "${GAMEFILESDIR}" || exit 1
run_server "${PROTON_PATH}/proton" run enshrouded_server.exe "${EXTRA_ARGS_ARRAY[@]}"
