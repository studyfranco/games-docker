# Space Engineers Dedicated Server

Docker image for the Space Engineers dedicated server (Steam app `298740`), a Windows only .NET Framework 4.8 server run with GE-Proton.

It is part of [games-docker](https://github.com/studyfranco/games-docker/tree/master) and built on `ghcr.io/studyfranco/games-docker:proton-dotnet48`: the server never runs as root (uid/gid `10000`) and the container can be read-only. The common rules (variables, config files, folders, several servers) are in the [README of master](https://github.com/studyfranco/games-docker/tree/master).

## Specials thanks

Based on the work of [jsknnr](https://github.com/jsknnr/space-engineers-container), [Devidian](https://github.com/Devidian/docker-spaceengineers) and [mmmaxwwwell](https://github.com/mmmaxwwwell/space-engineers-dedicated-docker-linux).

## Setup

The config and the world are created with the `Space Engineers Dedicated Server` tool, on Windows:

1. create and save your world with the tool
2. copy the files of the instance (`%AppData%\SpaceEngineersDedicated` by default):
   - `SpaceEngineers-Dedicated.cfg` to `/path/to/config/gameconfigs/`
   - the world (`Saves/<world>/` with its `Sandbox.sbc`) to `/path/to/config/saves/Saves/`

```bash
mkdir -p /path/to/config/gameconfigs /path/to/config/saves/Saves
# copy the config and the world
chown -R 10000:10000 /path/to/config
```

The image contains the Proton prefix of `proton-dotnet48`, with .NET Framework 4.8 and the core fonts. It is copied to `/config/compatdata` (about 1 GB) at the first start, and again when the Proton version of the image changes.

The `/config` folder holds:

- `/config/gamefiles`: server files
- `/config/gameconfigs`: `SpaceEngineers-Dedicated.cfg`
- `/config/saves`: instance of the server: worlds (`Saves/`), `Storage/` and logs of the last start
- `/config/backups`: backups
- `/config/compatdata`: Proton prefix with .NET Framework 4.8

### Docker Compose

```yaml
services:
  space-engineers:
    container_name: space-engineers-server
    hostname: space-engineers-server
    image: ghcr.io/studyfranco/games-docker:space-engineers
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
      - 27016:27016/udp
      # Remote API, only if you need it from outside
      #- 8080:8080/tcp
    expose:
      - 27016/udp
      - 8080/tcp
    environment:
      - "WORLD_NAME="
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

| Parameter          |  Default  | Function                                                 |
| ------------------ | :-------: | -------------------------------------------------------- |
| `WORLD_NAME`       |   empty   | world of `/config/saves/Saves` to load (empty: the one of the config, else the first one) |
| `BACKUP_RETENTION` |   `10`    | number of backups kept (`0`: keep all)                   |
| `SKIP_UPDATE`      |  `false`  | skip the server update at start                          |
| `EXTRA_ARGS`       |   empty   | additional arguments of the server                       |

All the settings of the server (name, port, password, admins, mods...) are in `SpaceEngineers-Dedicated.cfg`, the reference. Only `<LoadWorld>` and `<IP>` are adapted at each start to the paths and network of the container.

The mods of the world are downloaded by the server.

## Ports

| Port | Protocol | Use |
| ---- | :------: | --- |
| 27016 | UDP | game, used by the clients to connect |
| 8080 | TCP | remote API (publish it only if you need it from outside) |

## Features

- Backup at each start, and `docker exec space-engineers-server backup`
- Graceful stop on `docker stop`
- Automatic update from the host cron:

```cron
*/30 * * * * docker exec space-engineers-server update-check >> /var/log/games-update.log 2>&1
```

## Other Docker images

| | [games-docker](https://github.com/studyfranco/games-docker/tree/space-engineers) | [jsknnr/space-engineers-container](https://github.com/jsknnr/space-engineers-container) | [Devidian/docker-spaceengineers](https://github.com/Devidian/docker-spaceengineers) | [mmmaxwwwell/space-engineers-dedicated-docker-linux](https://github.com/mmmaxwwwell/space-engineers-dedicated-docker-linux) |
| --- | :---: | :---: | :---: | :---: |
| Runs without root | ✅ | ✅ | ❌ | ➖ |
| Read-only container | ✅ | ❌ | ❌ | ❌ |
| Automatic update of the running server | ✅ | ❌ | ❌ | ❌ |
| Backups of the saves | ✅ | ❌ | ❌ | ❌ |
| Graceful stop (`docker stop`) | ✅ | ❌ | ❌ | ❌ |
| Healthcheck | ✅ | ❌ | ✅ | ❌ |
| Mods | ✅ | ✅ | ✅ | ✅ |

✅ yes · ➖ partly (e.g. starts as root, then runs the server as a user) · ❌ no · ? not checked

Automatic update of games-docker: `update-check` from the host cron. Checked in the code of each image in October 2026.

## Last Update
2026-10-22
