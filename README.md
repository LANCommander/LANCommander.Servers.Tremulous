# Tremulous Server (Docker)

This repository provides a Dockerized **Tremulous** dedicated server. On first start it downloads the [GrangerHub](https://github.com/GrangerHub/tremulous) Tremulous 1.3 release `v1.3.0-alpha.0.15.2`, which holds both the game data and the Linux dedicated server (`tremded`), so you don't need to supply any files. It is the same release the LANCommander Tremulous package is built from. Tremulous is free software (GPLv2 engine and game code, CC-licensed content).
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- The GrangerHub `tremded` 1.3 Linux server, installed from the release zip (sha256-checked) or any zip of a Tremulous 1.3 install (e.g. the LANCommander archive)
- Serves 1.3 clients (protocol 71), plus 1.2 GPP (protocol 70) and 1.1 (protocol 69) clients on their own ports
- The server's name, map, map rotation, time limits, team balance and passwords are environment variables, written into a config file the server execs at startup
- LAN-only by default; one setting announces it to the internet master servers
- Optional HTTP file server for clients' fast downloads of custom `.pk3` files
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  tremulous:
    image: lancommander/tremulous:latest
    container_name: tremulous

    ports:
      - "30720:30720/udp"
      - "30721:30721/udp"
      - "30722:30722/udp"

    volumes:
      - ./config:/config

    environment:
      TREMULOUS_SERVER_NAME: "My Tremulous Server"
      TREMULOUS_MAP: "niveus"
      TREMULOUS_MAP_LIST: "niveus atcs karith nexus6 transit tremor uncreation arachnid2"
      TREMULOUS_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser finds servers by broadcasting to ports 30720-30723. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP (`/connect <ip>` in the console).

---

## Game Files

On first start `PostInitialization/20-InstallTremulous.ps1` downloads `TREMULOUS_SERVER_URL` (137 MB), checks it against `TREMULOUS_SERVER_SHA256` and unpacks `tremded`, `gpp/`, `gpp_11/` and `scripts/` into `config/Server/` (about 140 MB). The client, its renderers, the `granger` updater and Windows files are left out. It reinstalls only when `TREMULOUS_SERVER_URL` changes.

To install from your own copy instead, point `TREMULOUS_SERVER_URL` at a zip of a Tremulous 1.3 install with the Linux `tremded` (at its root or in one folder), e.g. the mounted LANCommander archive as `file:///path/to/archive.zip`, and clear `TREMULOUS_SERVER_SHA256`. Or copy the files into `config/Server/` yourself; the hook then leaves them alone.

Clients should run the same release (`v1.3.0-alpha.0.15.2`). The Linux release names its QVM pak `gpp/vms-v1.3.0-alpha.0.15.2.pk3`; the LANCommander package (built from the Windows release) has the same QVMs as `gpp/vms-v1.3.0-alpha.0.15_candidate.pk3`. The pak checksums match, so either works; installing from the LANCommander archive gives the server exactly the clients' files.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Tremulous: tremded, gpp/*.pk3, gpp_11/
    ├── Overlay/           # Your files, layered on top of Server/ (gpp/server.cfg, admin.dat, custom pk3s, generated lancommander.cfg and maprotation.cfg, logs)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The settings are written into `<TREMULOUS_GAME or gpp>/lancommander.cfg` on every start. Settings left empty are left out, so you can set them in `server.cfg` next to it instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `TREMULOUS_SERVER_URL` | Zip to install Tremulous from (`http(s)://` or `file://`) | the GrangerHub `v1.3.0-alpha.0.15.2` Linux64 zip |
| `TREMULOUS_SERVER_SHA256` | Expected SHA-256 of the zip; empty skips the check | hash of that zip |
| `TREMULOUS_GAME` | `fs_game`: empty for `gpp`, or a mod folder | |
| `TREMULOUS_PORT` | `net_port`, the 1.3 (protocol 71) port | `30720` |
| `TREMULOUS_ALT1_PORT` | `net_alt1port`, the 1.2 GPP (protocol 70) port | `30721` |
| `TREMULOUS_ALT2_PORT` | `net_alt2port`, the 1.1 (protocol 69) port | `30722` |
| `TREMULOUS_LEGACY_PROTOCOLS` | `true`: also serve 1.2 and 1.1 clients (`net_alternateProtocols 3`). `false`: 1.3 only (`0`). A number is passed as is | `true` |
| `TREMULOUS_LAN` | `true`: `dedicated 1`, LAN only. `false`: `dedicated 2`, announced to the internet master servers | `true` |
| `TREMULOUS_MAX_PLAYERS` | `sv_maxclients`, the player slots | `24` |
| `TREMULOUS_SERVER_NAME` | `sv_hostname` | `Tremulous Server` |
| `TREMULOUS_MOTD` | `g_motd`, shown to players while connecting | |
| `TREMULOUS_MAP` | First map. Empty with `TREMULOUS_MAP_LIST` set starts with the list's first map | `niveus` |
| `TREMULOUS_MAP_LIST` | Map rotation, separated by spaces or commas; written to `maprotation.cfg` | |
| `TREMULOUS_TIME_LIMIT` | `timelimit` in minutes; the match ends in a draw (0 = none) | `60` |
| `TREMULOUS_SUDDEN_DEATH_TIME` | `g_suddenDeathTime` in minutes: no more building (0 = none) | `50` |
| `TREMULOUS_TEAM_FORCE_BALANCE` | `g_teamForceBalance`: stop players joining the bigger team | `true` |
| `TREMULOUS_FRIENDLY_FIRE` | `g_friendlyFire` | |
| `TREMULOUS_PASSWORD` | `g_password`, required to join | |
| `TREMULOUS_RCON_PASSWORD` | `rconPassword`; empty disables remote console | |
| `TREMULOUS_PURE` | `sv_pure`: `1` makes clients use the server's pk3s only (engine default `1`) | |
| `TREMULOUS_ALLOW_DOWNLOAD` | `sv_allowDownload`: clients may download missing pk3s from the server | `1` |
| `TREMULOUS_DOWNLOAD_URL` | `sv_dlURL`, base URL for HTTP downloads (e.g. `http://<server ip>`). Empty = download over the game connection | |
| `HTTP_FILESERVER_ENABLED` | Serve `Merged/` on port 80 for `TREMULOUS_DOWNLOAD_URL` | `false` |
| `HTTP_FILESERVER_WEB_ROOT` | Directory served by the HTTP file server | `/config/Merged` |
| `HTTP_FILESERVER_FILE_PATTERN` | Regex of paths the HTTP file server allows | `.pk3` files in game folders |
| `START_EXE` | Launcher | `/usr/local/bin/tremulous-server` |
| `START_ARGS` | Extra command line, inserted before `+exec lancommander.cfg` (e.g. `+set g_humanBuildPoints 150`) | |

Stock maps: `arachnid2`, `atcs`, `karith`, `nexus6`, `niveus`, `transit`, `tremor`, `uncreation`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/tremulous:local .
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/tremulous:local .
```

---

## License

Tremulous is free software: its engine and game code are GPLv2 and its content is under Creative Commons licenses (see `COPYING`, `GPL` and `CC` in the release). It is downloaded at runtime and not included in the image.
This repository contains only Docker build logic and helper scripts licensed under MIT.
