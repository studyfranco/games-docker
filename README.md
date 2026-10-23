# Soulmask Dedicated Server

Docker image for the Soulmask dedicated server (Steam app `3017300`), native Linux server.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:master`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

My work are based on the docker server of satisfactory from [wolveix](https://github.com/wolveix/satisfactory-server), adapted for soulmask with the work of [jsknnr](https://github.com/jsknnr/soulmask-dedicated-server)

## Setup

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `Engine.ini`... (`WS/Saved/Config/LinuxServer`)
- `/config/gameplayconfig`: gameplay settings (`WS/Saved/GameplaySettings`)
- `/config/saves`: worlds (`WS/Saved/Worlds`)
- `/config/savesAccount`: accounts (`WS/Saved/Accounts`)
- `/config/logs`: logs of the server
- `/config/backups`: backups

### Docker Compose

```yaml
services:
  soulmask:
    container_name: soulmask-server
    hostname: soulmask-server
    image: ghcr.io/studyfranco/games-docker:soulmask
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
      #- "/var/log/soulmask/server_1:/config/logs"
    ports:
      - 8777:8777/udp
      - 27015:27015/udp
    expose:
      - 8777/udp
      - 27015/udp
      - 20000/tcp
    environment:
      - "SERVER_NAME=SoulmaskServerByMe"
      - "SERVER_PORT=8777"
      - "SERVER_QUERY_PORT=27015"
      - "SERVER_PASSWORD=password"
      - "SERVER_ADMIN_PASSWORD=adminpassword"
      - "MAX_PLAYERS=32"
      - "BACKUP_INTERVAL=900"
      - "SAVE_INTERVAL=600"
      - "GAME_MODE=pve"
      - "SERVER_LEVEL=Level01_Main"
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

All these settings are launch arguments of the server, applied at each start.

| Parameter               |  Default  | Function                                                 |
| ----------------------- | :-------: | -------------------------------------------------------- |
| `SERVER_NAME`           | `SoulmaskServerByMe` | name of the server                            |
| `SERVER_PORT`           |  `8777`   | game port, used by the clients to connect                |
| `SERVER_QUERY_PORT`     |  `27015`  | query port, used by Steam to get the server info         |
| `SERVER_PASSWORD`       |   empty   | server password (empty: public)                          |
| `SERVER_ADMIN_PASSWORD` |   empty   | admin password (empty: no admin)                         |
| `MAX_PLAYERS`           |   `32`    | player limit of the server                               |
| `RCON_PORT`             |   empty   | RCON port (RCON enabled when the port and the password are set) |
| `RCON_PASSWORD`         |   empty   | RCON password                                            |
| `ECHO_PORT`             |  `18888`  | port of the server console, used inside the container for the graceful stop |
| `BACKUP_INTERVAL`       |   `900`   | interval of the backups of the game, in seconds          |
| `SAVE_INTERVAL`         |   `600`   | interval of the saves, in seconds                        |
| `GAME_MODE`             |   `pve`   | `pve` or `pvp`                                           |
| `SERVER_LEVEL`          | `Level01_Main` | map of the server (`DLC_Level01_Main` for the DLC map) |
| `SERVER_ID`             |    `1`    | id of the server in a cluster                            |
| `MAIN_SERVER_PORT`      |  `20000`  | cluster port of the main server (empty on the other servers) |
| `TO_MAIN_SERVER`        |   empty   | address of the main server for the other servers of a cluster, e.g. `soulmask-server:20000` |
| `MOD_IDS`               |   empty   | Steam Workshop mods, comma separated IDs                 |
| `BACKUP_RETENTION`      |   `10`    | number of backups kept (`0`: keep all)                   |
| `SKIP_UPDATE`           |  `false`  | skip the server update at start                          |
| `EXTRA_ARGS`            |   empty   | additional arguments of the server                       |

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 8777 | UDP | game, used by the clients to connect |
| 27015 | UDP | Steam query |
| 20000 | TCP | cluster, between the containers only (not published) |

## Cluster example

The second server has its own `/config`, uses the game files, configs and gameplay settings of the first one, and connects to it (`SKIP_UPDATE=true`: the first server updates the game files).

```yaml
services:
  soulmask:
    # ... the service of docker-compose.yml, with:
    environment:
      - "SERVER_ID=1"
      - "MAIN_SERVER_PORT=20000"

  soulmask2:
    container_name: soulmask2-server
    hostname: soulmask2-server
    image: ghcr.io/studyfranco/games-docker:soulmask
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
      - "/path/to/config2:/config"
      - "/path/to/config/gamefiles:/config/gamefiles"
      - "/path/to/config/gameconfigs:/config/gameconfigs"
      - "/path/to/config/gameplayconfig:/config/gameplayconfig"
      - "/var/log/soulmask/server_2:/config/logs"
    ports:
      - 8778:8778/udp
      - 27016:27016/udp
    environment:
      - "SERVER_NAME=SoulmaskServerByMe2"
      - "SERVER_PORT=8778"
      - "SERVER_QUERY_PORT=27016"
      - "SERVER_PASSWORD=password"
      - "SERVER_ADMIN_PASSWORD=adminpassword"
      - "GAME_MODE=pve"
      - "SERVER_LEVEL=DLC_Level01_Main"
      - "SERVER_ID=2"
      - "MAIN_SERVER_PORT="
      - "TO_MAIN_SERVER=soulmask:20000"
      - "SKIP_UPDATE=true"
      - "TZ=Etc/UTC"
    tmpfs:
      - "/run:exec,mode=777"
      - "/tmp:exec,mode=777"
      - "/tmp/dumps:exec,mode=777"
      - "/var/tmp:exec,mode=777"
      - "/home/steam:exec,uid=10000,gid=10000,mode=700"
    restart: "unless-stopped"
    stop_grace_period: 1m
    depends_on:
      - soulmask
```

## Features

- Backup at each start, and `docker exec soulmask-server backup` (the game also makes its own backups, `BACKUP_INTERVAL`)
- Graceful stop on `docker stop` (`SaveAndExit` on the server console)
- Automatic update from the host cron:

```cron
*/30 * * * * docker exec soulmask-server update-check >> /var/log/games-update.log 2>&1
```

## Improve your experience

You can edit `/config/gameconfigs/Engine.ini` and the gameplay settings to choose other options.

## Other Docker images

This image replaces [studyfranco/soulmask-docker](https://github.com/studyfranco/soulmask-docker).

| | [games-docker](https://github.com/studyfranco/games-docker/tree/soulmask) | [jsknnr/soulmask-dedicated-server](https://github.com/jsknnr/soulmask-dedicated-server) |
| --- | :---: | :---: |
| Runs without root | ✅ | ✅ |
| Read-only container | ✅ | ❌ |
| Automatic update of the running server | ✅ | ❌ |
| Backups of the saves | ✅ | ➖ |
| Graceful stop (`docker stop`) | ✅ | ✅ |
| Healthcheck | ✅ | ❌ |
| Mods | ✅ | ✅ |
| Cluster of servers | ✅ | ❌ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
