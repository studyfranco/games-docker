#!/bin/bash

# Run by update-check before the restart: warn the players with the Palworld REST API and save the world

. /opt/game/palworld-api.sh

announce () {
    log_info "UPDATE: Announce: $1"
    palworld_api POST announce "$(jq -cn --arg m "$1" '{message: $m}')" >/dev/null \
        || log_warn "UPDATE: unable to send the message in game"
}

delay="${UPDATE_RESTART_DELAY}"
check_number delay 300

players=$(palworld_api GET players 2>/dev/null | jq '.players | length' 2>/dev/null || true)
if [[ "${players}" == "0" ]]; then
    log_info "UPDATE: No player connected, restarting now"
    delay=0
fi

if [ "${delay}" -gt 60 ]; then
    announce "Server update: restart in $(( (delay + 59) / 60 )) minutes"
    sleep $((delay - 60))
    delay=60
fi

if [ "${delay}" -gt 0 ]; then
    announce "Server update: restart in ${delay} seconds"
    sleep "${delay}"
fi

palworld_save
