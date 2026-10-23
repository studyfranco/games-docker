#!/bin/bash

# Palworld REST API from inside the container, used by update-hook.sh and backup-hook.sh
# Port and admin password are read in PalWorldSettings.ini (the reference)

. /usr/local/lib/games-docker/functions.sh

GAMECONFIG="/config/gameconfigs/PalWorldSettings.ini"

API_PORT=$(sed -n 's/.*RESTAPIPort=\([0-9]*\).*/\1/p' "${GAMECONFIG}")
API_PASSWORD=$(sed -n 's/.*AdminPassword="\([^"]*\)".*/\1/p' "${GAMECONFIG}")

if ! grep -q "RESTAPIEnabled=True" "${GAMECONFIG}"; then
    log_warn "RESTAPIEnabled is not True in ${GAMECONFIG}, the REST API can not be used"
fi

# palworld_api <method> <endpoint> [JSON body]
palworld_api () {
    local args=(-fsS -m 10 -u "admin:${API_PASSWORD}" -X "$1" -H "Content-Type: application/json")
    if [[ -n "$3" ]]; then
        args+=(-d "$3")
    fi
    curl "${args[@]}" "http://127.0.0.1:${API_PORT}/v1/api/$2"
}

palworld_save () {
    if palworld_api POST save >/dev/null; then
        log_info "World saved"
    else
        log_warn "Unable to save the world with the REST API"
    fi
}
