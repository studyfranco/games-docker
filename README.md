# Frozen Flame Dedicated Server

Docker image for the Frozen Flame dedicated server (Steam app `1348640`), native Linux server.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:master`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

My work are based on the docker server of satisfactory from [wolveix](https://github.com/wolveix/satisfactory-server), and the [official server documentation](https://github.com/DreamsideInteractive/FrozenFlameServer).

## Setup

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `Game.ini` (`FrozenFlame/Saved/Config/LinuxServer`), you can add `Engine.ini` and the game mode configs
- `/config/saves`: saves
- `/config/logs`: logs of the server
- `/config/backups`: backups

### Docker Compose

```yaml
services:
  frozen-flame:
    container_name: frozen-flame-server
    hostname: frozen-flame-server
    image: ghcr.io/studyfranco/games-docker:frozen-flame
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
      #- "/var/log/frozen-flame:/config/logs"
    ports:
      - 7779:7779/udp
      - 7780:7780/udp
      # RCON (admin commands), only if you need it from outside
      #- 27017:27017/tcp
    expose:
      - 7779/udp
      - 7780/udp
      - 27017/tcp
    environment:
      - "SERVER_NAME=FrozenFlameServer"
      - "SERVER_PORT=7779"
      - "SERVER_QUERY_PORT=7780"
      - "SERVER_PASSWORD=password"
      - "SERVER_ADMIN_PASSWORD=adminpassword"
      - "RCON_PORT=27017"
      - "MAX_PLAYERS=10"
      - "FREE_PVP=true"
      - "DAY_DURATION=3600"
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
| `SERVER_NAME`           | `FrozenFlameServer` | name of the server (launch argument)           |
| `SERVER_PORT`           |  `7779`   | game port, used by the clients to connect (launch argument) |
| `SERVER_QUERY_PORT`     |  `7780`   | query port, used by Steam to get the server info (launch argument) |
| `SERVER_PASSWORD`       |   empty   | server password (config, empty: public)                  |
| `SERVER_ADMIN_PASSWORD` |   empty   | RCON password, used for the admin commands (launch argument, empty: RCON disabled) |
| `RCON_PORT`             |  `27017`  | RCON port (launch argument)                              |
| `MAX_PLAYERS`           |   `10`    | player limit of the server (config)                      |
| `FREE_PVP`              |  `true`   | PVP for non-friends (config)                             |
| `DAY_DURATION`          |  `3600`   | how long a day lasts (config)                            |
| `GAME_CONFIG_URL`       | official `Game.ini` | example `Game.ini` downloaded at the first start |
| `BACKUP_RETENTION`      |   `10`    | number of backups kept (`0`: keep all)                   |
| `SKIP_UPDATE`           |  `false`  | skip the server update at start                          |
| `EXTRA_ARGS`            |   empty   | additional arguments of the server (e.g. `-noeac`)       |

The `(config)` settings are written in `Game.ini` only when it is created: then edit the file.

The admin commands ([RCON commands](https://github.com/DreamsideInteractive/FrozenFlameServer/blob/main/RCON.commands)) use the RCON port, with the password `admin:<SERVER_ADMIN_PASSWORD>`.

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 7779 | UDP | game, used by the clients to connect |
| 7780 | UDP | Steam query |
| 27017 | TCP | RCON, admin commands (publish it only if you need it from outside) |

## Features

- Backup at each start, and `docker exec frozen-flame-server backup`
- Graceful stop on `docker stop`
- Automatic update from the host cron:

```cron
*/30 * * * * docker exec frozen-flame-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

This image replaces [studyfranco/frozen-flame-docker](https://github.com/studyfranco/frozen-flame-docker).

| | [games-docker](https://github.com/studyfranco/games-docker/tree/frozen-flame) | [studyfranco/frozen-flame-docker](https://github.com/studyfranco/frozen-flame-docker) |
| --- | :---: | :---: |
| Runs without root | ✅ | ➖ |
| Read-only container | ✅ | ❌ |
| Automatic update of the running server | ✅ | ❌ |
| Backups of the saves | ✅ | ✅ |
| Graceful stop (`docker stop`) | ✅ | ❌ |
| Healthcheck | ✅ | ❌ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
