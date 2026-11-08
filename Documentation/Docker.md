---
sidebar_label: Docker
---

# Tremulous Docker Container

This Docker container runs a Tremulous dedicated server. It is built on the base image and runs the GrangerHub Tremulous 1.3 Linux server (`tremded`, release `v1.3.0-alpha.0.15.2`, the one the LANCommander Tremulous package is built from). The release zip is downloaded on first start and includes all game data, so you don't need to supply game files.

## Quick Start

```yaml
services:
  tremulous:
    image: lancommander/tremulous:latest
    container_name: tremulous

    ports:
      - 30720:30720/udp
      - 30721:30721/udp
      - 30722:30722/udp

    volumes:
      - "/data/Servers/Tremulous:/config"

    environment:
      TREMULOUS_SERVER_NAME: "My Tremulous Server"
      TREMULOUS_MAP_LIST: "niveus atcs karith nexus6 transit"
      TREMULOUS_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

## How It Starts

1. `PostInitialization/20-InstallTremulous.ps1` downloads `TREMULOUS_SERVER_URL` if `Server/tremded` or `Server/gpp/data-*.pk3` is missing or the URL changed, checks `TREMULOUS_SERVER_SHA256`, unpacks the folder holding `tremded` into `Server/` (without the client, renderers, `granger` and Windows files) and remounts the overlay.
2. `PostInitialization/30-ConfigureTremulous.ps1` writes the non-empty `TREMULOUS_*` settings into `<TREMULOUS_GAME or gpp>/lancommander.cfg` and `TREMULOUS_MAP_LIST` into `maprotation.cfg` next to it. It does this through `Merged/`, so the files land in `Overlay/`.
3. `START_EXE` (`/usr/local/bin/tremulous-server`) runs `./tremded +set dedicated <1|2> +set net_port <TREMULOUS_PORT> +set net_alt1port <..> +set net_alt2port <..> +set net_alternateProtocols <3|0> +set fs_basepath Merged +set fs_homepath Merged +set fs_game <TREMULOUS_GAME> <START_ARGS> +exec lancommander.cfg` from `Merged/`, line-buffered so its console output reaches `docker logs` straight away. `lancommander.cfg` ends by starting the first map.

A successful start ends with:

```
Opening IP socket: 0.0.0.0:30720
Opening alternate-1 IP socket: 0.0.0.0:30721
Opening alternate-2 IP socket: 0.0.0.0:30722
execing lancommander.cfg
sv_maxclients will be changed upon restarting.
------ Server Initialization ------
Server: niveus
...
------- Game Initialization -------
InitGame: \version\tremulous\protocol\71\...
```

## Configuration Options

### Ports

- **30720/udp**: Game, server info queries, rcon and LAN browser for 1.3 clients, protocol 71 (`TREMULOUS_PORT`, `net_port`).
- **30721/udp**: The same for 1.2 GPP clients, protocol 70 (`TREMULOUS_ALT1_PORT`, `net_alt1port`).
- **30722/udp**: The same for 1.1 clients, protocol 69 (`TREMULOUS_ALT2_PORT`, `net_alt2port`).
- **80/tcp**: HTTP downloads, only with `HTTP_FILESERVER_ENABLED=true`.

The two legacy ports are opened only with `TREMULOUS_LEGACY_PROTOCOLS=true` (the default). If a port is taken, the engine tries the next 9 ports up.

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### server.cfg and lancommander.cfg

`lancommander.cfg` is regenerated on every start; don't edit it. Put your own settings in `Overlay/<TREMULOUS_GAME or gpp>/server.cfg` (`set g_humanBuildPoints 150`, `set g_alienStage2Threshold 20`, `set g_allowVote 0`, ...):

- With `TREMULOUS_MAP` or `TREMULOUS_MAP_LIST` set, `lancommander.cfg` execs `server.cfg` first, then applies the `TREMULOUS_*` settings (which win) and starts the map. Leave a `TREMULOUS_*` setting empty to control it from `server.cfg`.
- With both empty, `lancommander.cfg` applies the `TREMULOUS_*` settings and execs `server.cfg` last, so `server.cfg` must start a map itself.

### Map rotation

Tremulous reads its rotations from `<game>/maprotation.cfg`. With `TREMULOUS_MAP_LIST` set, the hook writes a rotation named `lancommander` there and `lancommander.cfg` sets `g_initialMapRotation lancommander` before the first `map`:

```
lancommander
{
  karith
  atcs
  niveus
}
```

The game plays a rotation from its first entry once the first map ends, so the hook lists the maps after `TREMULOUS_MAP` first and `TREMULOUS_MAP` last (for `TREMULOUS_MAP=niveus`, `TREMULOUS_MAP_LIST=atcs niveus karith` above). When `TREMULOUS_MAP` isn't in the list, it is played once and then the list in order. A map ends when one team destroys the other's spawns or `timelimit` runs out.

An existing `maprotation.cfg` the hook didn't write is moved to `maprotation.cfg.bak` the first time `TREMULOUS_MAP_LIST` is set. To use your own rotations (with conditions, layouts and nested rotations), leave `TREMULOUS_MAP_LIST` empty, put `maprotation.cfg` in `Overlay/gpp/` and `set g_initialMapRotation <name>` in `server.cfg`. `/rcon nextmap` skips to the next map.

### Remote administration

In the game console: `/rconpassword <TREMULOUS_RCON_PASSWORD>`, then `/rcon status`, `/rcon map atcs`, `/rcon kick <name>`. Out of game, any Quake 3 rcon tool works on UDP 30720.

The in-game admin commands (`!kick`, `!ban`, `!nextmap`, `!setlevel`, ...) also run over rcon, without the `!` and with full rights: `/rcon nextmap`, `/rcon setlevel <player> 5`. Admin levels are stored in `gpp/admin.dat`, which the server writes into `Overlay/gpp/`.

### HTTP downloads

Clients can fetch missing custom `.pk3` files over HTTP instead of the slow in-game UDP download: set `HTTP_FILESERVER_ENABLED=true`, `TREMULOUS_DOWNLOAD_URL=http://<server ip>` and keep `TREMULOUS_ALLOW_DOWNLOAD=1`. The file server only allows `<game>/<name>.pk3` paths. The engine's own default `sv_dlURL` is `http://downloads.tremulous.net`, which a LAN can't reach, so the image sets it to empty unless `TREMULOUS_DOWNLOAD_URL` is set.

### Hooks

| Hook | When |
|------|------|
| `PreInstallTremulous` / `PostInstallTremulous` | Around the Tremulous download |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **`SHA256 mismatch`**: `TREMULOUS_SERVER_URL` points at a different zip than the GrangerHub `v1.3.0-alpha.0.15.2` Linux64 zip. Clear `TREMULOUS_SERVER_SHA256` (or set the zip's hash).
- **`tremded not found`** when installing from the LANCommander archive: the package must include the Linux tree (the LANCommander Package script merges the Windows and Linux release zips; both are needed).
- **`vms-v1.3.0-alpha.0.15.2.pk3` vs `vms-v1.3.0-alpha.0.15_candidate.pk3`**: the Linux release and the LANCommander package (built from the Windows release) name their QVM pak differently. The contents are identical, so the pak checksums match and pure servers accept either; installing from the LANCommander archive gives the server the clients' exact file.
- **The server isn't in the in-game LAN list**: the LAN browser broadcasts to ports 30720-30723 on the local network, so the container has to be on the LAN (macvlan/ipvlan or host networking) and the ports in that range. Joining by IP always works.
- **The first map plays twice in a row**: a hand-written rotation lists the start map first; see [Map rotation](#map-rotation).
- **`rcon status` lists every slot with ping 999**: that's how this build prints empty slots; `getinfo` reports the real client count.
- **`couldn't exec autogen_server.cfg` / `couldn't exec autoexec.cfg`** or **`could not open admin config file admin.dat`** at startup: harmless; those files don't exist until something creates them.
- **`WARNING: CM_GridPlane unresolvable`** while loading `karith`: harmless map geometry warnings.
