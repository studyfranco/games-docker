#!/bin/bash

# Backup of the saves and configs in /config/backups, kept BACKUP_RETENTION times
# From the host cron: docker exec <container> backup
# At start (run.sh): backup --start (server not running, the game hook is not used)

set -e

. /usr/local/lib/games-docker/functions.sh

if [[ "$1" != "--start" ]]; then
    # Also log in the container output (docker logs)
    exec > >(tee -a /proc/1/fd/1) 2>&1
fi

dirs=()
for dir in ${BACKUP_DIRS}; do
    if [ -d "/config/${dir}" ]; then
        dirs+=("${dir}")
    fi
done

if [ -z "$(ls -A /config/saves 2>/dev/null)" ]; then
    log_info "BACKUP: No save in /config/saves, nothing to backup"
    exit 0
fi

# Game specific part: save the world before the backup...
if [[ "$1" != "--start" ]] && [ -x "${GAME_BACKUP_HOOK}" ]; then
    "${GAME_BACKUP_HOOK}" || log_warn "BACKUP: the game backup hook failed"
fi

archive="/config/backups/$(date +"%Y_%m_%d_%H_%M_%S").tar.gz"
log_info "BACKUP: ${dirs[*]} to ${archive}"
tar cf - -C /config "${dirs[@]}" | pigz -9 > "${archive}.tmp"
mv "${archive}.tmp" "${archive}"

check_number BACKUP_RETENTION 10
if [ "${BACKUP_RETENTION}" -gt 0 ]; then
    ls -1t /config/backups/*.tar.gz | tail -n +$((BACKUP_RETENTION + 1)) | xargs -r rm -f
fi
