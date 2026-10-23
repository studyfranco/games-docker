# Satisfactory Dedicated Server

Docker image for the Satisfactory dedicated server (Steam app `1690800`), native Linux server.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:master`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

Settings based on the work of [robtme (wolveix)](https://github.com/robtme/satisfactory-server).

## Setup

The server needs 8 to 16 GB of RAM.

The first player to connect claims the server in the game and sets its name and admin password: the image has no admin password.

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `Engine.ini`, `Game.ini`... (`FactoryGame/Saved/Config/LinuxServer`)
- `/config/saves`: saves and blueprints
- `/config/logs`: logs of the server
- `/config/backups`: backups

### Docker Compose

```yaml
services:
  satisfactory:
    container_name: satisfactory-server
    hostname: satisfactory-server
    image: ghcr.io/studyfranco/games-docker:satisfactory
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
      #- "/var/log/satisfactory:/config/logs"
    ports:
      - 7777:7777/udp
      - 7777:7777/tcp
      - 8888:8888/tcp
    expose:
      - 7777/udp
      - 7777/tcp
      - 8888/tcp
    environment:
      - "SERVER_PORT=7777"
      - "SERVER_MESSAGING_PORT=8888"
      - "MAX_PLAYERS=4"
      - "AUTOSAVE_NUM=5"
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
    stop_grace_period: 1m
```

Then `docker compose up -d`.

## Environment Variables

All these settings are launch arguments of the server, applied at each start.

| Parameter                 |  Default  | Function                                                  |
| ------------------------- | :-------: | --------------------------------------------------------- |
| `SERVER_PORT`             |  `7777`   | game port (UDP) and HTTPS API (TCP)                       |
| `SERVER_MESSAGING_PORT`   |  `8888`   | messaging port (TCP), the same inside and outside         |
| `MAX_PLAYERS`             |    `4`    | player limit of the server                                |
| `AUTOSAVE_NUM`            |    `5`    | number of rotating autosave files                         |
| `MAX_OBJECTS`             | `2162688` | object limit of the server                                |
| `MAX_TICK_RATE`           |   `30`    | maximum sim tick rate of the server                       |
| `TIMEOUT`                 |   `30`    | client timeout, in seconds                                |
| `SERVER_STREAMING`        |  `true`   | asset streaming of the server                             |
| `DISABLE_SEASONAL_EVENTS` |  `false`  | disable the FICSMAS event                                 |
| `MULTIHOME`               |   `::`    | listening interface of the server                         |
| `GAME_BRANCH`             |   empty   | Steam branch (`experimental` for the experimental version) |
| `BACKUP_RETENTION`        |   `10`    | number of backups kept (`0`: keep all)                    |
| `SKIP_UPDATE`             |  `false`  | skip the server update at start                           |
| `EXTRA_ARGS`              |   empty   | additional arguments of the server                        |

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 7777 | UDP | game |
| 7777 | TCP | HTTPS API of the server |
| 8888 | TCP | messaging |

## Features

- Backup at each start, and `docker exec satisfactory-server backup` (the game also keeps `AUTOSAVE_NUM` autosaves)
- Graceful stop on `docker stop`
- Healthcheck with the HTTPS API of the server
- Automatic update from the host cron:

```cron
*/30 * * * * docker exec satisfactory-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

| | [games-docker](https://github.com/studyfranco/games-docker/tree/satisfactory) | [robtme/satisfactory-server](https://github.com/robtme/satisfactory-server) | [jsknnr/satisfactory-server](https://github.com/jsknnr/satisfactory-server) |
| --- | :---: | :---: | :---: |
| Runs without root | ✅ | ➖ | ✅ |
| Read-only container | ✅ | ❌ | ❌ |
| Automatic update of the running server | ✅ | ❌ | ❌ |
| Backups of the saves | ✅ | ✅ | ❌ |
| Graceful stop (`docker stop`) | ✅ | ✅ | ✅ |
| Healthcheck | ✅ | ✅ | ❌ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
