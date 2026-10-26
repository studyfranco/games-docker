---
name: add-game-image
description: Add a new game dedicated server image to the games-docker repository, as a new branch built on master, proton, wine or proton-dotnet48. Use when asked to add, create, port or migrate a game server Docker image, container or branch in this repository, or to fix the image of an existing game.
---

# Add a game server image to games-docker

The README of the `master` branch describes the conventions for the users. This skill is the procedure for the agents. Read the files of an existing game branch close to the new game before writing anything (`git show <branch>:run.sh`).

## How the repository works

- One image per branch, published as `ghcr.io/studyfranco/games-docker:<branch>` by the GitHub Actions of `master`.
- Base images (branches):
  - `master`: Debian testing, steamcmd, base of the native Linux servers
  - `proton`: GE-Proton in `/opt/proton`, base of the Windows only servers
  - `wine`: Wine of WineHQ (classic WoW64), only when a server does not work with Proton
  - `proton-dotnet48`: `proton` + a prefix with .NET Framework 4.8 and the core fonts, base of the .NET servers
- The entrypoint `/init.sh` of the base does all the steamcmd part: it checks that every folder of `CONFIG_DIRS` is writable, copies steamcmd to `~/steamcmd`, installs or updates `STEAM_APP_ID` in `/config/gamefiles` (`GAME_PLATFORM`, `GAME_BRANCH`, a lock for shared game files, a retry, the installed version kept when Steam fails), then runs `/opt/game/run.sh`.
- A game branch only contains: `Dockerfile`, `run.sh` (and optional hooks or templates), `docker-compose.yml`, `README.md`, `LICENSE`, `.github/`, `.forgejo/`. Never `init.sh`, `update-check.sh`, `backup.sh`, `functions.sh` or the prefix scripts: they come from the base image.
- Tools in the base image: `jq`, `pigz`, `curl`, `procps`, `flock`. `/usr/local/lib/games-docker/functions.sh`: `log_info`, `log_warn`, `check_number`, `link_dir`, `link_file`, `set_ini_key`, `sed_escape`, `admin_password`, `config_seeded` / `mark_config_seeded`, `start_log_tail`, `run_server`, `EXTRA_ARGS_ARRAY`. Commands: `backup`, `update-check`.
- `proton` adds `proton-build-prefix` (build time: prepare a prefix in `PROTON_PREFIX_TEMPLATE`, verbs `prefix`, `dotnet48` or any winetricks verb) and `proton-prefix-init` (start: copy that prefix to `/config/compatdata`). `wine` has the same with `wine-build-prefix` and `wine-prefix-init`.

## Rules of the images

- Security: user `steam` (uid/gid `10000`), never root at runtime; the container runs with `read_only: true`: write only in `/config` and the tmpfs (`/tmp`, `/home/steam`). Game scripts are copied to `/opt/game/` (owned by root), never into `/home/steam` (tmpfs).
- No `apt install` in a game image, except runtime libraries or tools specific to the game (e.g. `libatomic1 libpulse0` for Valheim). Common tools go in `master`.
- Variables with underscores: `SERVER_NAME`, `SERVER_PORT`, `SERVER_QUERY_PORT`, `SERVER_PASSWORD`, `SERVER_ADMIN_PASSWORD` (wherever the game has an admin password), `MAX_PLAYERS`, `RCON_PORT`, `RCON_PASSWORD`, `SAVE_INTERVAL`, `MOD_IDS`... Never a new variable starting with `STEAM_`: Valve's scripts read them (`STEAM_PLATFORM` broke steamcmd). Only `STEAM_APP_ID` and Proton's `STEAM_COMPAT_*`.
- Settings written in a config file of the game are applied only when the file is created, then the file is the reference (the user's changes are never overwritten). When the server creates the file itself, apply them once with `config_seeded <name> || { ...; mark_config_seeded <name>; }`. Settings given as launch arguments (ports...) are applied at each start. A new config gets `$(admin_password)`: `SERVER_ADMIN_PASSWORD`, or a random one shown in the logs.
- Folders: link the game folders to `/config/gameconfigs`, `/config/saves`, `/config/logs` with `link_dir` (and `link_file` for a single file), so each container uses its own folders even when `/config/gamefiles` is shared. Extend `CONFIG_DIRS` (`/config/logs` only if the game writes log files) and `BACKUP_DIRS` (folders of `/config` in the backups) in the Dockerfile.
- Logs: in `docker logs`. If the server does not print its log to stdout, `start_log_tail <log file>`.
- Graceful stop: define `shutdown_server` (usually `pkill -INT -f '[N]ame-of-the-binary'`, or a save command on the console of the game, with a SIGINT fallback), then start the server with `run_server <command> ... "${EXTRA_ARGS_ARRAY[@]}"`.
- `backup --start` at the beginning of `run.sh`. Optional hooks: `/opt/game/update-hook.sh` (warn the players in game before an update restart) and `/opt/game/backup-hook.sh` (save the world before a backup), always through an API or console of the game called from inside the container (see `palworld`).
- Healthcheck: the game port open in `/proc/net/udp` (or an API of the server, see `satisfactory`), `--start-period=15m`.

## Steps

1. **Research the server**: dedicated server Steam app id (not the game one), Linux or Windows only, executable and launch arguments, config files and their paths, saves, logs, ports and protocols, admin password, how to stop it gracefully, mods. Read the Dockerfile and scripts of the existing Docker images of the game (GitHub), they are also needed for the comparison table of the README. Check the depots with `curl -fsSL https://api.steamcmd.net/v1/info/<appid>`.
2. **Choose the base**: native Linux server → `master`; Windows server → `proton`; .NET Framework 4.8 → `proton-dotnet48`; `wine` only if Proton was tested and fails.
3. **Create the branch** from its base: `git checkout -b <game> <base>`, then `git rm` the files of the base (`init.sh update-check.sh backup.sh functions.sh`, and `proton-*.sh` / `wine-*.sh`). Branch name in lowercase with dashes, it is also the image tag.
4. **Dockerfile**, e.g. a Proton game:

   ```dockerfile
   FROM ghcr.io/studyfranco/games-docker:proton

   LABEL maintainer="studyfranco@gmail.com"

   # Game start script run by /init.sh, outside HOME (tmpfs) and owned by root
   COPY --chmod=755 run.sh /opt/game/run.sh

   ENV STEAM_APP_ID="<server app id>" \
       SERVER_NAME="<Game>ServerByMe" \
       SERVER_PORT=<port> \
       SERVER_PASSWORD="" \
       SERVER_ADMIN_PASSWORD="" \
       MAX_PLAYERS=<n>
   ENV CONFIG_DIRS="${CONFIG_DIRS} /config/logs"

   EXPOSE <port>/udp

   # The server is up when its game port is open (first start: download + prefix creation)
   HEALTHCHECK --interval=30s --timeout=5s --start-period=15m --retries=3 \
       CMD awk '{print $2}' /proc/net/udp | grep -qi ":$(printf '%04X' "${SERVER_PORT}")$" || exit 1
   ```

5. **run.sh**:

   ```bash
   #!/bin/bash

   set -e

   . /usr/local/lib/games-docker/functions.sh

   GAMEFILESDIR="/config/gamefiles"
   GAMECONFIG="/config/gameconfigs/<config file>"

   shutdown_server () {
       pkill -INT -f '[G]ameServer-Win64-Shipping.exe' || true
   }

   check_number SERVER_PORT <port>
   check_number MAX_PLAYERS <n> 1 <max>

   ## Backup at each start
   backup --start

   ## Configs, saves and logs in /config
   link_dir "${GAMEFILESDIR}/<Game>/Saved/Config/WindowsServer" "/config/gameconfigs"
   link_dir "${GAMEFILESDIR}/<Game>/Saved/SaveGames" "/config/saves"
   link_dir "${GAMEFILESDIR}/<Game>/Saved/Logs" "/config/logs"

   ## Settings applied only when the config is created, then the file is the reference
   if [ ! -f "${GAMECONFIG}" ]; then
       ...
       set_ini_key "${GAMECONFIG}" "AdminPassword" "$(admin_password)"
   fi

   ## Server log to the container output
   start_log_tail "${GAMEFILESDIR}/<Game>/Saved/Logs/<Game>.log"

   log_info "Starting <Game> Dedicated Server"

   # Relative exe path so Proton launches it directly; with an absolute path it goes
   # through umu.exe, which blocks the server at startup once lsteamclient is enabled.
   cd "${GAMEFILESDIR}/<Game>/Binaries/Win64" || exit 1
   run_server "${PROTON_PATH}/proton" run GameServer-Win64-Shipping.exe -Port="${SERVER_PORT}" -log "${EXTRA_ARGS_ARRAY[@]}"
   ```

   Native server: `run_server ./GameServer.sh ...` from `/config/gamefiles`. .NET server (`proton-dotnet48`): call `proton-prefix-init` before `run_server`.
6. **docker-compose.yml**: copy the one of a game branch (`read_only`, `init`, `no-new-privileges`, the `cap_drop` list, the tmpfs including `/home/steam:exec,uid=10000,gid=10000,mode=700`, `restart: "unless-stopped"`, `stop_grace_period`) and adapt the name, ports and environment. Never a tmpfs or a volume inside `/config/gamefiles`: Docker would create its folders as root.
7. **README.md**, simple and easy to read by humans, with the layout of the other games: title and one sentence · Specials thanks · Setup (`chown -R 10000:10000`, the folders of `/config`, the docker compose inline) · Environment Variables (say which ones are config and which ones are launch arguments) · Ports · sections of the game (admins, mods, cluster...) · Features · Improve your experience · Other Docker images (links and a comparison table: Runs without root, Read-only container, Automatic update of the running server, Backups of the saves, Graceful stop, Healthcheck, and Mods or Cluster when relevant; ✅ yes · ➖ partly · ❌ no · ? not checked; only claim what was seen in the code of each image) · Last Update.
8. **CI and master**: in `master`, add the branch to the push branches of `.github/workflows/docker-publish.yml` and to the matrix of the workflow after its base (`master` → `docker-publish-second.yml`, `proton` or `wine` → `docker-publish-third.yml`, `proton-dotnet48` → `docker-publish-fourth.yml`), and a row to the table of the README of `master`. Then copy `.github` from `master` to every branch (the workflows must be the same everywhere).
9. **Check**: `bash -n` on every script. Docker may not be available locally: the CI builds the images. The logs of GitHub Actions need a login, but the failure annotations are public (`/repos/studyfranco/games-docker/check-runs/<job id>/annotations`) and the images on ghcr.io can be pulled anonymously: to debug a build, keep the logs in a file of the image and read its layers (`https://ghcr.io/token?scope=repository:studyfranco/games-docker:pull`). To debug an apt dependency problem, simulate it with an isolated `APT_CONFIG` (testing has i386/amd64 version skews).
10. **Git**: end the commit messages with the `Co-Authored-By` line given by the system. The owner keeps one commit per branch on top of its base branch, and squashes the history after a change: ask before rewriting or force-pushing the published branches.

## Known pitfalls

- GE-Proton 11: `proton run` with a relative exe path (an absolute path goes through `umu.exe`), `lsteamclient` is enabled by the `proton` image, `UMU_ID=0`.
- Windows depots need `GAME_PLATFORM=windows` (set by `proton` and `wine`).
- .NET Framework 4.8 under Proton: install it as Windows 7 (on Windows 10 the installer thinks it is built in); the winetricks `dotnet40` step fails in Proton. Already done in `proton-dotnet48`.
- An EXIT trap whose last command fails changes the exit code of a `set -e` script.
- Shared game files (several servers): the first container updates them, the others use `SKIP_UPDATE=true`; `update-check` restarts them when the files changed.
