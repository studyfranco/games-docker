# Conan Exiles Enhanced Dedicated Server

Docker image for the Conan Exiles Enhanced dedicated server (Steam app `443030`, Unreal Engine 5 version), native Linux server.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:master`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

Launch arguments and mods based on the work of [indifferentbroccoli](https://github.com/indifferentbroccoli/conan-exiles-enhanced-server-docker).

## Setup

The server needs 8 to 16 GB of RAM.

For the UE4 version of the server, set `GAME_BRANCH=conan-exiles-legacy`.

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files and mods
- `/config/gameconfigs`: `Game.ini`, `ServerSettings.ini`... (`ConanSandbox/Saved/Config/LinuxServer`)
- `/config/saves`: `ConanSandbox/Saved`: the world (`game.db`) and its backups
- `/config/logs`: logs of the server
- `/config/backups`: backups

### Docker Compose

```yaml
services:
  conan-exiles:
    container_name: conan-exiles-server
    hostname: conan-exiles-server
    image: ghcr.io/studyfranco/games-docker:conan-exiles-enhanced
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
      #- "/var/log/conan-exiles:/config/logs"
    ports:
      - 7777:7777/udp
      # Pinger port, always SERVER_PORT + 1
      - 7778:7778/udp
      - 27015:27015/udp
      # RCON, only if you need it from outside
      #- 25575:25575/tcp
    expose:
      - 7777/udp
      - 7778/udp
      - 27015/udp
      - 25575/tcp
    environment:
      - "SERVER_NAME=ConanExilesServerByMe"
      - "SERVER_PORT=7777"
      - "SERVER_QUERY_PORT=27015"
      - "SERVER_PASSWORD=password"
      - "SERVER_ADMIN_PASSWORD=adminpassword"
      - "MAX_PLAYERS=40"
      - "RCON_PASSWORD="
      - "MOD_IDS="
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
| `SERVER_NAME`           | `ConanExilesServerByMe` | name of the server (launch argument)       |
| `SERVER_PORT`           |  `7777`   | game port, the pinger port is `SERVER_PORT + 1` (launch argument) |
| `SERVER_QUERY_PORT`     |  `27015`  | query port, used by Steam to get the server info (launch argument) |
| `SERVER_PASSWORD`       |   empty   | server password (launch argument, empty: public)         |
| `SERVER_ADMIN_PASSWORD` |   empty   | admin password (config, empty: random, shown in the logs) |
| `MAX_PLAYERS`           |   `40`    | player limit of the server (launch argument)             |
| `RCON_PORT`             |  `25575`  | RCON port (config)                                       |
| `RCON_PASSWORD`         |   empty   | RCON password (config, empty: RCON disabled)             |
| `MOD_IDS`               |   empty   | Steam Workshop mods, comma separated IDs (downloaded at each start, in this order) |
| `GAME_BRANCH`           |   empty   | Steam branch (`conan-exiles-legacy` for the UE4 version) |
| `BACKUP_RETENTION`      |   `10`    | number of backups kept (`0`: keep all)                   |
| `SKIP_UPDATE`           |  `false`  | skip the server and mods update at start                 |
| `EXTRA_ARGS`            |   empty   | additional arguments of the server                       |

The `(config)` settings are written in `Game.ini` and `ServerSettings.ini` only when they are created: then edit the files.

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 7777 | UDP | game, used by the clients to connect |
| 7778 | UDP | pinger, always the game port + 1 |
| 27015 | UDP | Steam query |
| 25575 | TCP | RCON (publish it only if you need it from outside) |

## Features

- Backup at each start, and `docker exec conan-exiles-server backup`
- Mods of the Steam Workshop
- Graceful stop on `docker stop`
- Automatic update from the host cron:

```cron
*/30 * * * * docker exec conan-exiles-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

| | [games-docker](https://github.com/studyfranco/games-docker/tree/conan-exiles-enhanced) | [indifferentbroccoli/conan-exiles-enhanced-server-docker](https://github.com/indifferentbroccoli/conan-exiles-enhanced-server-docker) |
| --- | :---: | :---: |
| Runs without root | ✅ | ➖ |
| Read-only container | ✅ | ❌ |
| Automatic update of the running server | ✅ | ❌ |
| Backups of the saves | ✅ | ❌ |
| Graceful stop (`docker stop`) | ✅ | ✅ |
| Healthcheck | ✅ | ✅ |
| Mods | ✅ | ✅ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
