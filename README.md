# Enshrouded Dedicated Server

Docker image for the Enshrouded dedicated server (Steam app `2278520`), a Windows only server run with GE-Proton.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:proton`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

Proton setup and default configuration based on the work of [jsknnr](https://github.com/jsknnr/enshrouded-server) (MIT).

## Setup

The first start is long: download of the server and creation of the Wine prefix.

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `enshrouded_server.json`
- `/config/saves`: savegames
- `/config/logs`: logs of the server
- `/config/backups`: backups
- `/config/compatdata`: Wine prefix

### Docker Compose

```yaml
services:
  enshrouded:
    container_name: enshrouded-server
    hostname: enshrouded-server
    image: ghcr.io/studyfranco/games-docker:enshrouded
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
      #- "/var/log/enshrouded:/config/logs"
    ports:
      - 15637:15637/udp
      - 27015:27015/udp
    expose:
      - 15637/udp
      - 27015/udp
    environment:
      - "SERVER_NAME=EnshroudedServerByMe"
      - "SERVER_PORT=15637"
      - "SERVER_PASSWORD=password"
      - "SERVER_ADMIN_PASSWORD=adminpassword"
      - "MAX_PLAYERS=16"
      - "VOICE_CHAT_MODE=Proximity"
      - "ENABLE_VOICE_CHAT=false"
      - "ENABLE_TEXT_CHAT=false"
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

All these settings are written in `enshrouded_server.json` only when it is created (first start): then edit the file.

| Parameter               |  Default  | Function                                                 |
| ----------------------- | :-------: | -------------------------------------------------------- |
| `SERVER_NAME`           | `EnshroudedServerByMe` | name of the server                          |
| `SERVER_PORT`           |  `15637`  | query port, used by the game and Steam                   |
| `SERVER_PASSWORD`       |   empty   | password of the `Friend` group, the players (empty: public) |
| `SERVER_ADMIN_PASSWORD` |   empty   | password of the `Admin` group (empty: random, shown in the logs) |
| `MAX_PLAYERS`           |   `16`    | player limit of the server (1-16)                        |
| `VOICE_CHAT_MODE`       |   empty   | `Proximity` or `Global` (empty: `Proximity`)             |
| `ENABLE_VOICE_CHAT`     |   empty   | `true` or `false` (empty: `false`)                       |
| `ENABLE_TEXT_CHAT`      |   empty   | `true` or `false` (empty: `false`)                       |
| `BACKUP_RETENTION`      |   `10`    | number of backups kept (`0`: keep all)                   |
| `SKIP_UPDATE`           |  `false`  | skip the server update at start                          |
| `EXTRA_ARGS`            |   empty   | additional arguments of the server                       |

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 15637 | UDP | game and query, used by the clients to connect |
| 27015 | UDP | Steam |

## Admins and players

Enshrouded has no admin account: the players get the permissions of the user group whose password they enter. The created config has two groups:

- `Admin`: all the permissions (kick and ban, inventories, world, bases)
- `Friend`: the players, no kick and ban, can not extend the bases

You can change the permissions, add groups or banned accounts (`bannedAccounts`) in `/config/gameconfigs/enshrouded_server.json`. Keep `saveDirectory` and `logDirectory` to `./savegame` and `./logs`.

## Features

- Backup at each start, and `docker exec enshrouded-server backup`
- Graceful stop on `docker stop`
- Automatic update from the host cron (the game has no admin console, the players are not warned in game):

```cron
*/30 * * * * docker exec enshrouded-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

| | [games-docker](https://github.com/studyfranco/games-docker/tree/enshrouded) | [jsknnr/enshrouded-server](https://github.com/jsknnr/enshrouded-server) | [indifferentbroccoli/enshrouded-server-docker](https://github.com/indifferentbroccoli/enshrouded-server-docker) |
| --- | :---: | :---: | :---: |
| Runs without root | ✅ | ✅ | ➖ |
| Read-only container | ✅ | ❌ | ❌ |
| Automatic update of the running server | ✅ | ❌ | ❌ |
| Backups of the saves | ✅ | ❌ | ❌ |
| Graceful stop (`docker stop`) | ✅ | ✅ | ✅ |
| Healthcheck | ✅ | ❌ | ✅ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
