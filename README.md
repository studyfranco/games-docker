# Palworld Dedicated Server

Docker image for the Palworld dedicated server (Steam app `2394010`), native Linux server.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:master`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

My work are based on the docker server of satisfactory from [wolveix](https://github.com/wolveix/satisfactory-server)

## Setup

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `PalWorldSettings.ini`
- `/config/saves`: saves
- `/config/logs`: logs of the server
- `/config/backups`: backups

### Docker Compose

```yaml
services:
  palworld:
    container_name: palworld-server
    hostname: palworld-server
    image: ghcr.io/studyfranco/games-docker:palworld
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
      #- "/var/log/palworld:/config/logs"
    ports:
      - 8211:8211/udp
      - 27015:27015/udp
    expose:
      - 8211/udp
      - 27015/udp
    environment:
      - "SERVER_NAME=PalworldServerByMe"
      - "SERVER_PORT=8211"
      - "SERVER_QUERY_PORT=27015"
      - "SERVER_PASSWORD=password"
      - "SERVER_ADMIN_PASSWORD=adminpassword"
      - "MAX_PLAYERS=32"
      - "MAX_PLAYERS_COOP=32"
      - "MAX_PLAYERS_GUILD=32"
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

| Parameter               |  Default  | Function                                                 |
| ----------------------- | :-------: | -------------------------------------------------------- |
| `SERVER_NAME`           | `PalworldServerByMe` | name of the server (config)                   |
| `SERVER_PORT`           |  `8211`   | game port, used by the clients to connect (launch argument) |
| `SERVER_QUERY_PORT`     |  `27015`  | query port, used by Steam to get the server info (launch argument) |
| `SERVER_PASSWORD`       |   empty   | server password (config, empty: public)                  |
| `SERVER_ADMIN_PASSWORD` |   empty   | admin password, also used by RCON and the REST API (config, empty: random, shown in the logs) |
| `MAX_PLAYERS`           |   `32`    | player limit of the server (config)                      |
| `MAX_PLAYERS_COOP`      |   `32`    | player limit in coop (config)                            |
| `MAX_PLAYERS_GUILD`     |   `32`    | player limit of a guild (config)                         |
| `RCON_PORT`             |  `25575`  | RCON port (config)                                       |
| `REST_API_PORT`         |  `8212`   | REST API port, used inside the container by the hooks, not published (config) |
| `UPDATE_RESTART_DELAY`  |   `300`   | seconds between the in game message and the restart of an update (`0` when nobody is connected) |
| `BACKUP_RETENTION`      |   `10`    | number of backups kept (`0`: keep all)                   |
| `SKIP_UPDATE`           |  `false`  | skip the server update at start                          |
| `EXTRA_ARGS`            |   empty   | additional arguments of `PalServer.sh`                   |

The `(config)` settings are written in `PalWorldSettings.ini` only when it is created: then edit the file.

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 8211 | UDP | game, used by the clients to connect |
| 27015 | UDP | Steam query |
| 8212 | TCP | REST API, inside the container only (not published) |
| 25575 | TCP | RCON, inside the container only (not published) |

## Features

- Backup at each start, and `docker exec palworld-server backup` (the world is saved before with the REST API)
- Graceful stop on `docker stop`
- Automatic update from the host cron, with in game messages and a save before the restart:

```cron
*/30 * * * * docker exec palworld-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

This image replaces [studyfranco/palworld-docker](https://github.com/studyfranco/palworld-docker).

| | [games-docker](https://github.com/studyfranco/games-docker/tree/palworld) | [jsknnr/palworld-server](https://github.com/jsknnr/palworld-server) |
| --- | :---: | :---: |
| Runs without root | ✅ | ✅ |
| Read-only container | ✅ | ❌ |
| Automatic update of the running server | ✅ | ❌ |
| Players warned before an update restart | ✅ | ❌ |
| Backups of the saves | ✅ | ❌ |
| Graceful stop (`docker stop`) | ✅ | ❌ |
| Healthcheck | ✅ | ❌ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
