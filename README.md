# games-docker

Docker images for game dedicated servers, one image per branch, all published as `ghcr.io/studyfranco/games-docker:<branch>`.

> **Made with AI**: this project was generated with an AI (Claude, by Anthropic), guided and tested by [studyfranco](https://github.com/studyfranco).
> Everyone is free to fork, copy and modify it, under the [AGPL-3.0](LICENSE) license (share your changes under the same license).

| Branch / tag       | Based on  | Content                                                        |
| ------------------ | --------- | -------------------------------------------------------------- |
| `master`           | Debian    | steamcmd, base of the native Linux servers                     |
| `proton`           | `master`  | GE-Proton, base of the Windows only servers                    |
| `wine`             | `master`  | Wine of WineHQ, base of the Windows only servers that need Wine instead of Proton |
| `proton-dotnet48`  | `proton`  | Proton prefix with .NET Framework 4.8 and the core fonts, base of the .NET servers |
| `palworld`         | `master`  | Palworld dedicated server                                      |
| `soulmask`         | `master`  | Soulmask dedicated server                                      |
| `frozen-flame`     | `master`  | Frozen Flame dedicated server                                  |
| `valheim`          | `master`  | Valheim dedicated server                                       |
| `satisfactory`     | `master`  | Satisfactory dedicated server                                  |
| `conan-exiles-enhanced` | `master` | Conan Exiles Enhanced dedicated server                   |
| `enshrouded`       | `proton`  | Enshrouded dedicated server                                    |
| `voyagers-of-nera` | `proton`  | Voyagers of Nera dedicated server                              |
| `icarus`           | `proton`  | Icarus dedicated server                                        |
| `space-engineers`  | `proton-dotnet48` | Space Engineers dedicated server                       |

All the images are designed to be simple and secure:

- the servers never run as root (user `steam`, uid/gid `10000`)
- the containers can run with a read-only filesystem: everything written outside `/config` goes to tmpfs (`/tmp`, `/home/steam`)
- no privilege escalation needed, and the capabilities a game server never needs are dropped
- one container per server: for another server of the same game, add a container using the same game files

The game images only add their start script: the tools (`jq`, `pigz`, ...) are in the base image.

## Base image

At start, `/init.sh`:

1. checks that every folder of `CONFIG_DIRS` is writable: mount the whole `/config`, or one volume per folder (owned by `10000:10000`)
2. copies steamcmd to `~/steamcmd` (HOME, tmpfs) when missing, updates it and links its Steam client libraries in `~/.steam/sdk32` and `sdk64`
3. installs or updates the game `STEAM_APP_ID` in `/config/gamefiles` (unless `SKIP_UPDATE=true`)
4. runs the start script of the game image, `/opt/game/run.sh`: the game images only copy their `run.sh` there

| Parameter          |  Default  | Function                                                   |
| ------------------ | :-------: | ---------------------------------------------------------- |
| `STEAM_APP_ID`     |   empty   | Steam app of the server to install                         |
| `GAME_PLATFORM`    |   empty   | force the platform of the downloaded depots (`windows` in `proton`) |
| `GAME_BRANCH`      |   empty   | Steam beta branch of the server                            |
| `SKIP_UPDATE`      |  `false`  | skip the server update at start                            |
| `EXTRA_ARGS`       |   empty   | additional arguments given to the server                   |
| `BACKUP_RETENTION` |   `10`    | number of backups kept (`0`: keep all)                     |
| `BACKUP_DIRS`      | `saves gameconfigs` | folders of `/config` in the backups             |
| `CONFIG_DIRS`      | `/config/backups /config/gamefiles /config/saves /config/gameconfigs` | folders that must be writable, extended by the game images |
| `GAME_RUN_SCRIPT`  | `/opt/game/run.sh` | start script of the game                          |
| `GAME_UPDATE_HOOK` | `/opt/game/update-hook.sh` | optional game script run by `update-check` before the restart |
| `GAME_BACKUP_HOOK` | `/opt/game/backup-hook.sh` | optional game script run by `backup` before the archive |

## Conventions of the game images

### Variables

All the variables use underscores: `SERVER_NAME`, `SERVER_PORT`, `SERVER_QUERY_PORT`, `SERVER_PASSWORD`, `SERVER_ADMIN_PASSWORD` (when the game has an admin password), `MAX_PLAYERS`, `RCON_PORT`, `RCON_PASSWORD`, `SKIP_UPDATE`, `BACKUP_RETENTION`, `EXTRA_ARGS`...

### Settings: the config files are the reference

- The settings written in a config file of the game are only applied when the file is created (first start): then the file is the reference, your changes in it are never overwritten. To apply the variables again, delete the file.
- The settings given as launch arguments (ports...) are applied at each start.

### Folders

| Path                  | Content                                                   |
| --------------------- | --------------------------------------------------------- |
| `/config/gamefiles`   | game files, can be shared by several containers           |
| `/config/gameconfigs` | config files of the server                                |
| `/config/saves`       | saves                                                     |
| `/config/backups`     | backups                                                   |
| `/config/logs`        | log files of the game (games writing log files)           |

The game folders are links to these folders, so each container uses its own folders even when the game files are shared. The main log of the game is also shown in `docker logs`.

When you mount a folder inside another mounted folder (e.g. `/config/logs` in `/config`), create it before on the host with the right owner: otherwise Docker creates it, and its parents, as root and the server can not write in them.

```bash
mkdir -p /path/to/config/logs && chown -R 10000:10000 /path/to/config
```

### Several servers with the same game files

Add a container with its own `/config` (or its own `saves`, `gameconfigs`, `logs`...) and the same `/config/gamefiles`. Set `SKIP_UPDATE=true` on the other servers: the first one updates the game files (one update at a time, with a lock), and `update-check` restarts the others when the game files changed.

### Docker compose

```yaml
    read_only: true
    init: true
    security_opt:
      - "no-new-privileges:true"
    cap_drop:
      - NET_RAW
      - MKNOD
      - AUDIT_WRITE
      - SYS_CHROOT
      - SETFCAP
      - SETPCAP
      - SYS_ADMIN
      - SYS_PTRACE
      - SYS_MODULE
    tmpfs:
      - "/run:exec,mode=777"
      - "/tmp:exec,mode=777"
      - "/tmp/dumps:exec,mode=777"
      - "/var/tmp:exec,mode=777"
      - "/home/steam:exec,uid=10000,gid=10000,mode=700"
    restart: "unless-stopped"
```

## Automatic updates

Each image contains `update-check`, to run from the cron of the host. It compares the installed build of the game with the latest build of the Steam branch, and when they differ:

1. the game hook warns the players in game when the game allows it (and saves)
2. the server is stopped gracefully
3. Docker restarts the container (`restart: unless-stopped` is required) and `init.sh` installs the update

All the containers of these images (label `games-docker.update-check`), every 30 minutes:

```cron
*/30 * * * * docker ps -q --filter label=games-docker.update-check | xargs -r -I{} docker exec {} update-check >> /var/log/games-update.log 2>&1
```

Or a single container:

```cron
*/30 * * * * docker exec palworld-server update-check >> /var/log/games-update.log 2>&1
```

`docker exec <container> update-check --check` only checks (exit code `10` when an update is available).

## Backups

A backup of the saves and configs (`BACKUP_DIRS`) is made at each start in `/config/backups`, `BACKUP_RETENTION` backups are kept. Each image also contains `backup`, to run from the cron of the host (the game hook saves the world before when the game allows it):

```cron
0 */6 * * * docker ps -q --filter label=games-docker.update-check | xargs -r -I{} docker exec {} backup >> /var/log/games-backup.log 2>&1
```

## Last Update
2026-10-22
