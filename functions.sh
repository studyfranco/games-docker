#!/bin/bash

# Shared functions of the game start scripts: . /usr/local/lib/games-docker/functions.sh

NUMCHECK='^[0-9]+$'

# Quick function to generate a timestamp
timestamp () {
    date +"%Y-%m-%d %H:%M:%S,%3N"
}

log_info () {
    echo "$(timestamp) INFO: $*"
}

log_warn () {
    echo "$(timestamp) WARN: $*"
}

# Check that a variable is a number (and optionally in a range), set its default value otherwise
# check_number <variable name> <default> [min] [max]
check_number () {
    local name="$1" default="$2" min="$3" max="$4" value="${!1}"
    if ! [[ "${value}" =~ ${NUMCHECK} ]] \
        || { [[ -n "${min}" ]] && [ "${value}" -lt "${min}" ]; } \
        || { [[ -n "${max}" ]] && [ "${value}" -gt "${max}" ]; }; then
        log_warn "Invalid ${name} given: ${value}, using ${default}"
        printf -v "${name}" '%s' "${default}"
    fi
}

# Replace a game directory by a symlink to a persistent directory in /config (existing files are kept)
# link_dir <path expected by the game> <directory in /config>
link_dir () {
    mkdir -p "$2" "$(dirname "$1")"
    if [ -d "$1" ] && [ ! -L "$1" ]; then
        cp -a "$1/." "$2/"
        rm -rf "$1"
    fi
    ln -sfn "$2" "$1"
}

# Replace a game file by a symlink to a persistent file in /config
# When the game replaced the symlink by a regular file, its version is kept
# link_file <path expected by the game> <file in /config>
link_file () {
    mkdir -p "$(dirname "$1")" "$(dirname "$2")"
    if [ -f "$1" ] && [ ! -L "$1" ]; then
        mv -f "$1" "$2"
    fi
    ln -sfn "$2" "$1"
}

# Escape a value for the replacement part of a sed command
sed_escape () {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

# Set a key of a single section ini file, added at the end when missing
# set_ini_key <file> <key> <value>
set_ini_key () {
    if grep -q "^$2=" "$1"; then
        sed -i "s/^$2=.*/$2=$(sed_escape "$3")/" "$1"
    else
        printf '%s=%s\n' "$2" "$3" >> "$1"
    fi
}

# Admin password of a new config: SERVER_ADMIN_PASSWORD, or a random one shown in the logs
admin_password () {
    if [[ -z "${SERVER_ADMIN_PASSWORD}" ]]; then
        SERVER_ADMIN_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20)
        log_warn "SERVER_ADMIN_PASSWORD not set, generated admin password: ${SERVER_ADMIN_PASSWORD}" >&2
    fi
    printf '%s' "${SERVER_ADMIN_PASSWORD}"
}

# Settings written in the config files of the game are only applied once, then the files are the reference.
# For the configs created by the game itself: config_seeded <name> || { ...apply...; mark_config_seeded <name>; }
config_seeded () {
    [ -e "/config/gameconfigs/.seeded-$1" ]
}

mark_config_seeded () {
    touch "/config/gameconfigs/.seeded-$1"
}

# Show a log file of the game in the container output (docker logs)
start_log_tail () {
    mkdir -p "$(dirname "$1")"
    tail -F -n 0 "$1" 2>/dev/null &
    LOG_TAIL_PID=$!
}

# Default graceful stop of the server, games can define their own shutdown_server
shutdown_server () {
    kill -INT "${SERVER_PID}" 2>/dev/null || true
}

# Run the server in background until it exits, with a graceful stop on SIGTERM (docker stop)
# run_server <command> [arguments...]
run_server () {
    trap 'echo ""; log_info "Received SIGTERM, shutting down gracefully"; shutdown_server' TERM INT

    "$@" &
    SERVER_PID=$!

    # wait returns as soon as the trap fires, so loop until the server exits (saved and stopped)
    while kill -0 "${SERVER_PID}" 2>/dev/null; do
        wait "${SERVER_PID}" || true
    done

    if [[ -n "${LOG_TAIL_PID}" ]]; then
        kill "${LOG_TAIL_PID}" 2>/dev/null || true
    fi

    log_info "Shutdown complete."
}

# steamcmd stops when it can not read the CPU frequency (some virtual machines): "Unable to determine CPU Frequency"
if ! grep -qE '^cpu MHz[[:space:]]*:[[:space:]]*[1-9]' /proc/cpuinfo 2>/dev/null; then
    export CPU_MHZ="1500.000"
fi

# Additional arguments of the server from EXTRA_ARGS
read -ra EXTRA_ARGS_ARRAY <<< "${EXTRA_ARGS}"
