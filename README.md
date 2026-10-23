# Voyagers of Nera Dedicated Server

Docker image for the Voyagers of Nera dedicated server (Steam app `3937860`), a Windows only server run with GE-Proton.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:proton`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Setup

The first start is long: download of the server and creation of the Wine prefix.

The server creates its settings file at its first start: restart the container once to apply the environment variables (only this time, then the file is the reference).

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `CustomHostUserSettings.ini` and `CustomGameUserSettings.ini`
- `/config/saves`: savegame (`BoatGame/Saved/PersistedData`)
- `/config/logs`: logs of the server
- `/config/backups`: backups
- `/config/compatdata`: Wine prefix

### Docker Compose

```yaml
services:
  voyagers-of-nera:
    container_name: voyagers-of-nera
    hostname: voyagers-of-nera
    image: ghcr.io/studyfranco/games-docker:voyagers-of-nera
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
      #- "/var/log/voyagers-of-nera:/config/logs"
    ports:
      - 7777:7777/udp
      - 27015:27015/udp
    expose:
      - 7777/udp
      - 27015/udp
    environment:
      - "SERVER_NAME=VoyagersOfNeraServerByMe"
      - "SERVER_PORT=7777"
      - "SERVER_QUERY_PORT=27015"
      - "SERVER_PASSWORD=password"
      - "MAX_PLAYERS=10"
      - "SAVE_INTERVAL=300"
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

| Parameter           |  Default  | Function                                            |
| ------------------- | :-------: | --------------------------------------------------- |
| `SERVER_NAME`       | `VoyagersOfNeraServerByMe` | name of the server (config)        |
| `SERVER_PORT`       |  `7777`   | game port, used by the clients to connect (launch argument) |
| `SERVER_QUERY_PORT` |  `27015`  | Steam query port (launch argument)                  |
| `SERVER_PASSWORD`   |   empty   | server password (config, empty: public)             |
| `MAX_PLAYERS`       |   `10`    | player limit of the server, 1-10 (config)           |
| `SAVE_INTERVAL`     |   `300`   | autosave timer in seconds, 10-900 (config)          |
| `BACKUP_RETENTION`  |   `10`    | number of backups kept (`0`: keep all)              |
| `SKIP_UPDATE`       |  `false`  | skip the server update at start                     |
| `EXTRA_ARGS`        |   empty   | additional arguments of the server                  |

The game has no known admin password.

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 7777 | UDP | game, used by the clients to connect |
| 27015 | UDP | Steam query |

## Features

- Backup at each start, and `docker exec voyagers-of-nera backup`
- Graceful stop on `docker stop`
- Automatic update from the host cron (the game has no admin console, the players are not warned in game):

```cron
*/30 * * * * docker exec voyagers-of-nera update-check >> /var/log/games-update.log 2>&1
```

## Improve your experience

You can edit `/config/gameconfigs/CustomGameUserSettings.ini` to change the gameplay (gathering rate, damages, durability...).

## Other Docker images

This image replaces [studyfranco/voyagers-of-nera-docker](https://github.com/studyfranco/voyagers-of-nera-docker).

| | [games-docker](https://github.com/studyfranco/games-docker/tree/voyagers-of-nera) | [studyfranco/voyagers-of-nera-docker](https://github.com/studyfranco/voyagers-of-nera-docker) |
| --- | :---: | :---: |
| Runs without root | ✅ | ➖ |
| Read-only container | ✅ | ❌ |
| Automatic update of the running server | ✅ | ❌ |
| Backups of the saves | ✅ | ❌ |
| Graceful stop (`docker stop`) | ✅ | ❌ |
| Healthcheck | ✅ | ❌ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
