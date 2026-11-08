# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Tremulous Game Server" \
      org.opencontainers.image.description="Dedicated server for Tremulous 1.3 (the GrangerHub tremded build, v1.3.0-alpha.0.15.2)" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Tremulous" \
      app.lancommander.server.external-id.hq="5d079077-2632-4549-91e1-41f53bd6e1ce" \
      app.lancommander.server.external-id.igdb="93105"

# ----------------------------
# Server settings
#   - TREMULOUS_SERVER_URL is the GrangerHub v1.3.0-alpha.0.15.2 Linux64 release zip (game data and
#     tremded), the release the LANCommander Tremulous package is built from. It is unpacked into
#     /config/Server on first start and verified against TREMULOUS_SERVER_SHA256 (empty = no check).
#     Any zip with tremded and gpp/data-*.pk3 works (file:// too, e.g. the LANCommander archive)
#   - The TREMULOUS_* settings below are written into <TREMULOUS_GAME or gpp>/lancommander.cfg on
#     every start, which the server execs at startup. Empty settings are left out
#   - TREMULOUS_MAP_LIST is written to <game>/maprotation.cfg as the rotation "lancommander"
#   - The optional HTTP file server serves Merged/ for clients' HTTP downloads
#     (TREMULOUS_DOWNLOAD_URL), limited to .pk3 files
# ----------------------------
ENV TREMULOUS_SERVER_URL="https://github.com/GrangerHub/tremulous/releases/download/v1.3.0-alpha.0.15.2/tremulous-v1.3.0-alpha.0.15.2-Linux64.zip" \
    TREMULOUS_SERVER_SHA256="41d82fa8c4822786fc412fec91edd777ce4bb785f2beb054273e4f18f942f364" \
    TREMULOUS_GAME="" \
    TREMULOUS_PORT="30720" \
    TREMULOUS_ALT1_PORT="30721" \
    TREMULOUS_ALT2_PORT="30722" \
    TREMULOUS_LEGACY_PROTOCOLS="true" \
    TREMULOUS_LAN="true" \
    TREMULOUS_MAX_PLAYERS="24" \
    TREMULOUS_SERVER_NAME="Tremulous Server" \
    TREMULOUS_MOTD="" \
    TREMULOUS_MAP="niveus" \
    TREMULOUS_MAP_LIST="" \
    TREMULOUS_TIME_LIMIT="60" \
    TREMULOUS_SUDDEN_DEATH_TIME="50" \
    TREMULOUS_TEAM_FORCE_BALANCE="true" \
    TREMULOUS_FRIENDLY_FIRE="" \
    TREMULOUS_PASSWORD="" \
    TREMULOUS_RCON_PASSWORD="" \
    TREMULOUS_PURE="" \
    TREMULOUS_ALLOW_DOWNLOAD="1" \
    TREMULOUS_DOWNLOAD_URL="" \
    HTTP_FILESERVER_ENABLED="false" \
    HTTP_FILESERVER_WEB_ROOT="/config/Merged" \
    HTTP_FILESERVER_FILE_PATTERN="^/[^/]+/[^/]+\.pk3$" \
    START_EXE="/usr/local/bin/tremulous-server" \
    START_ARGS=""

# tremded links libc, libm, libstdc++ and libgcc_s
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libstdc++6 \
        unzip && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/tremulous-server /usr/local/bin/tremulous-server
RUN chmod +x /usr/local/bin/tremulous-server

COPY Hooks/ "${BASE_HOOKS}/"

# 30720/udp: game, server info queries, rcon and LAN browser, Tremulous 1.3 protocol (TREMULOUS_PORT)
# 30721/udp: same for 1.2 (GPP) clients (TREMULOUS_ALT1_PORT, when TREMULOUS_LEGACY_PROTOCOLS=true)
# 30722/udp: same for 1.1 clients (TREMULOUS_ALT2_PORT, when TREMULOUS_LEGACY_PROTOCOLS=true)
# 80/tcp:    HTTP downloads, when HTTP_FILESERVER_ENABLED=true
EXPOSE 30720/udp
EXPOSE 30721/udp
EXPOSE 30722/udp
EXPOSE 80/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
