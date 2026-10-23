# Icarus Dedicated Server

Docker image for the Icarus dedicated server (Steam app `2089300`), a Windows only server run with GE-Proton.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:proton`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Setup

Large prospects need more memory map areas on the **docker host** (otherwise the server logs `Ran out of memory allocating` while the system has enough memory):

```bash
echo "vm.max_map_count=262144" >> /etc/sysctl.conf && sysctl -p
```

The first start is long: download of the server (about 20 GB) and creation of the Wine prefix. The server needs more than 8 GB of RAM (16 GB recommended).

The query port must be the same inside and outside the container, otherwise the server is not visible in the server browser.

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `ServerSettings.ini` and `Engine.ini`
- `/config/saves`: prospects
- `/config/logs`: logs of the server
- `/config/backups`: backups
- `/config/compatdata`: Wine prefix

### Docker Compose

```yaml
services:
  icarus:
    container_name: icarus-server
    hostname: icarus-server
    image: ghcr.io/studyfranco/games-docker:icarus
    #network_mode: "host"
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
    volumes:
      # Must be owned by 10000:10000 (chown -R 10000:10000 /path/to/config)
      - "/path/to/config:/config"
      # Optional, game files and logs elsewhere (create the folders before, owned by 10000:10000)
      #- "/path/to/gamefiles:/config/gamefiles"
      #- "/var/log/icarus:/config/logs"
    ports:
      # The query port must be the same inside and outside the container
      - 17777:17777/udp
      - 27015:27015/udp
    expose:
      - 17777/udp
      - 27015/udp
    environment:
      - "SERVER_NAME=IcarusServerByMe"
      - "SERVER_PORT=17777"
      - "SERVER_QUERY_PORT=27015"
      - "SERVER_PASSWORD=password"
      - "SERVER_ADMIN_PASSWORD=adminpassword"
      - "MAX_PLAYERS=8"
      - "SHUTDOWN_NOT_JOINED_FOR=-1"
      - "SHUTDOWN_EMPTY_FOR=-1"
      - "ALLOW_NON_ADMINS_LAUNCH=True"
      - "ALLOW_NON_ADMINS_DELETE=False"
      - "LOAD_PROSPECT="
      - "CREATE_PROSPECT="
      - "RESUME_PROSPECT=True"
      - "STEAM_ASYNC_TIMEOUT=60"
      - "GAME_BRANCH=public"
      - "BACKUP_RETENTION=10"
      - "TZ=Etc/UTC"
    tmpfs:
      - "/run:exec,mode=777"
      - "/tmp:exec,mode=777"
      - "/tmp/dumps:exec,mode=777"
      - "/var/tmp:exec,mode=777"
      - "/home/steam:exec,uid=10000,gid=10000,mode=700"
    restart: "unless-stopped"
    stop_grace_period: 90s
```

Then `docker compose up -d`.

## Environment Variables

| Parameter                 |  Default  | Function                                                      |
| ------------------------- | :-------: | ------------------------------------------------------------- |
| `SERVER_NAME`             | `IcarusServerByMe` | name of the server (64 characters max)               |
| `SERVER_PORT`             |  `17777`  | game port, used by the clients to connect                     |
| `SERVER_QUERY_PORT`       |  `27015`  | query port, used by Steam to get the server info              |
| `MAX_PLAYERS`             |    `8`    | player limit of the server, 1-8 (config)                      |
| `SERVER_PASSWORD`         |   empty   | password to join the server, empty: no password (config)      |
| `SERVER_ADMIN_PASSWORD`   |   empty   | admin password, `/AdminLogin` (config, empty: random, shown in the logs) |
| `SHUTDOWN_NOT_JOINED_FOR` |   `-1`    | seconds before a started prospect returns to the lobby if nobody joins (`-1`: never) |
| `SHUTDOWN_EMPTY_FOR`      |   `-1`    | seconds before the server returns to the lobby once empty (`-1`: never) |
| `ALLOW_NON_ADMINS_LAUNCH` |  `True`   | all the players can launch a prospect from the lobby          |
| `ALLOW_NON_ADMINS_DELETE` |  `False`  | all the players can delete a prospect from the lobby          |
| `LOAD_PROSPECT`           |   empty   | prospect to load at start                                     |
| `CREATE_PROSPECT`         |   empty   | prospect to create at start: `Type Difficulty(1-4) Hardcore(True/False) SaveName` |
| `RESUME_PROSPECT`         |  `True`   | resume the last prospect at start                             |
| `STEAM_ASYNC_TIMEOUT`     |   `60`    | `AsyncTaskTimeout` of Steam in `Engine.ini` (slow systems and connections) |
| `GAME_BRANCH`             |   empty   | Steam branch of the server (empty: `public`)                  |
| `BACKUP_RETENTION`        |   `10`    | number of backups kept (`0`: keep all)                        |
| `SKIP_UPDATE`             |  `false`  | skip the server update at start                               |
| `EXTRA_ARGS`              |   empty   | additional arguments of the server                            |

`SERVER_NAME`, `SERVER_PORT` and `SERVER_QUERY_PORT` are launch arguments (each start). The other settings are written in `ServerSettings.ini` and `Engine.ini` only when they are created (first start): then edit the files.

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 17777 | UDP | game, used by the clients to connect |
| 27015 | UDP | Steam query, the same inside and outside the container |

## Features

- Backup at each start, and `docker exec icarus-server backup`
- Graceful stop on `docker stop`
- Automatic update from the host cron (the game has no admin console, the players are not warned in game):

```cron
*/30 * * * * docker exec icarus-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

This image replaces [studyfranco/icarus-server](https://github.com/studyfranco/icarus-server).

| | [games-docker](https://github.com/studyfranco/games-docker/tree/icarus) | [mornedhels/icarus-server](https://github.com/mornedhels/icarus-server) | [indifferentbroccoli/icarus-server-docker](https://github.com/indifferentbroccoli/icarus-server-docker) | [jsknnr/icarus-helm](https://github.com/jsknnr/icarus-helm) |
| --- | :---: | :---: | :---: | :---: |
| Runs without root | ✅ | ➖ | ➖ | ✅ |
| Read-only container | ✅ | ❌ | ❌ | ❌ |
| Automatic update of the running server | ✅ | ✅ | ❌ | ❌ |
| Backups of the saves | ✅ | ❌ | ❌ | ❌ |
| Graceful stop (`docker stop`) | ✅ | ✅ | ✅ | ❌ |
| Healthcheck | ✅ | ❌ | ✅ | ❌ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
