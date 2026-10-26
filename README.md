# Valheim Dedicated Server

Docker image for the Valheim dedicated server (Steam app `896660`), native Linux server, vanilla (BepInEx when you install it).

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:master`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

Launch arguments and BepInEx environment based on the work of [mbround18](https://github.com/mbround18/valheim-docker).

## Setup

The folder mounted on `/config` must be owned by `10000:10000`:

```bash
mkdir -p /path/to/config && chown -R 10000:10000 /path/to/config
```

The `/config` folder holds:

- `/config/gamefiles`: server files (and BepInEx)
- `/config/gameconfigs`: admin, banned and permitted lists
- `/config/saves`: worlds (`-savedir`)
- `/config/backups`: backups

The logs of the server are in `docker logs`.

### Docker Compose

```yaml
services:
  valheim:
    container_name: valheim-server
    hostname: valheim-server
    image: ghcr.io/studyfranco/games-docker:valheim
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
      # Optional, game files elsewhere (create the folder before, owned by 10000:10000)
      #- "/path/to/gamefiles:/config/gamefiles"
    ports:
      - 2456:2456/udp
      - 2457:2457/udp
    expose:
      - 2456/udp
      - 2457/udp
    environment:
      - "SERVER_NAME=ValheimServerByMe"
      - "SERVER_PORT=2456"
      - "SERVER_PASSWORD=password"
      - "WORLD_NAME=Dedicated"
      - "PUBLIC=1"
      - "CROSSPLAY=false"
      - "PRESET="
      - "MODIFIERS="
      - "SET_KEYS="
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

| Parameter          |  Default  | Function                                                 |
| ------------------ | :-------: | -------------------------------------------------------- |
| `SERVER_NAME`      | `ValheimServerByMe` | name of the server                             |
| `SERVER_PORT`      |  `2456`   | game port (the server also uses the next one, `2457`)    |
| `SERVER_PASSWORD`  |   empty   | server password, at least 5 characters, not in the name (required) |
| `WORLD_NAME`       | `Dedicated` | name of the world                                      |
| `PUBLIC`           |    `1`    | `1`: in the server list, `0`: hidden                     |
| `CROSSPLAY`        |  `false`  | crossplay with the other platforms                       |
| `PRESET`           |   empty   | `Normal`, `Casual`, `Easy`, `Hard`, `Hardcore`, `Immersive` or `Hammer` |
| `MODIFIERS`        |   empty   | world modifiers, e.g. `combat=hard,raids=none`           |
| `SET_KEYS`         |   empty   | global keys, e.g. `nobuildcost,playerevents`             |
| `SAVE_INTERVAL`    |  `1800`   | interval of the saves, in seconds                        |
| `BACKUP_RETENTION` |   `10`    | number of backups kept (`0`: keep all)                   |
| `SKIP_UPDATE`      |  `false`  | skip the server update at start                          |
| `EXTRA_ARGS`       |   empty   | additional arguments of the server                       |

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 2456 | UDP | game, used by the clients to connect |
| 2457 | UDP | Steam query |

## Admins

Valheim has no admin password: the admins, banned and permitted players are lists of IDs (`Steam_76561198...`), one per line, in `/config/gameconfigs`:

- `adminlist.txt`
- `bannedlist.txt`
- `permittedlist.txt` (when not empty, only these players can join)

## Mods

The image is vanilla. To use mods, install [BepInExPack_Valheim](https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/) and the mods in `/config/gamefiles` (`BepInEx/`, `doorstop_libs/`...): the server is started with BepInEx when `BepInEx/core/BepInEx.Preloader.dll` is present. The update of the server keeps these files.

## Features

- Backup at each start, and `docker exec valheim-server backup` (Valheim also keeps its own world backups)
- Graceful stop on `docker stop`
- Automatic update from the host cron:

```cron
*/30 * * * * docker exec valheim-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

| | [games-docker](https://github.com/studyfranco/games-docker/tree/valheim) | [community-valheim-tools/valheim-server-docker](https://github.com/community-valheim-tools/valheim-server-docker) | [mbround18/valheim-docker](https://github.com/mbround18/valheim-docker) |
| --- | :---: | :---: | :---: |
| Runs without root | ✅ | ➖ | ✅ |
| Read-only container | ✅ | ❌ | ❌ |
| Automatic update of the running server | ✅ | ✅ | ✅ |
| Backups of the saves | ✅ | ✅ | ✅ |
| Graceful stop (`docker stop`) | ✅ | ✅ | ? |
| Healthcheck | ✅ | ❌ | ✅ |
| Mods | ➖ | ✅ | ✅ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
