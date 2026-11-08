#Requires -Modules Logging

# Write the TREMULOUS_* settings into <TREMULOUS_GAME or gpp>/lancommander.cfg, which
# tremulous-server execs at startup. The file is regenerated on every start and ends by starting
# the first map. Put your own settings in server.cfg next to it (in Overlay/): lancommander.cfg
# execs it first, so the TREMULOUS_* settings win, or last when TREMULOUS_MAP is empty, so it
# starts the map.
#
# TREMULOUS_MAP_LIST is written to <game>/maprotation.cfg as the rotation "lancommander", which
# the game starts through g_initialMapRotation. A maprotation.cfg that this hook didn't write is
# kept as maprotation.cfg.bak.

$game = if ($Env:TREMULOUS_GAME) { $Env:TREMULOUS_GAME } else { 'gpp' }
$dir = Join-Path $Env:SERVER_ROOT $game
$file = Join-Path $dir 'lancommander.cfg'
$header = '// Generated from the TREMULOUS_* environment variables on every start'

if (-not (Get-ChildItem -Path (Join-Path $Env:SERVER_ROOT 'gpp') -Filter 'data-*.pk3' -File -ErrorAction SilentlyContinue)) {
    Write-Log -Level Error "gpp/data-*.pk3 not found in $Env:SERVER_ROOT; set TREMULOUS_SERVER_URL or copy Tremulous into $Env:SERVER_DIR"
    return
}

if ($game -ne 'gpp' -and -not (Test-Path -Path $dir)) {
    Write-Log -Level Warning "TREMULOUS_GAME=$game, but $dir doesn't exist; copy the mod folder into $Env:SERVER_DIR"
}

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '').Replace(';', '') + '"' }

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', '1', 'yes') { '1' } elseif ($Value -in 'false', '0', 'no') { '0' } else { $Value }
}

$values = [ordered]@{
    'sv_hostname'        = $(if ($Env:TREMULOUS_SERVER_NAME) { ConvertTo-Quoted $Env:TREMULOUS_SERVER_NAME })
    'g_motd'             = $(if ($Env:TREMULOUS_MOTD) { ConvertTo-Quoted $Env:TREMULOUS_MOTD })
    'sv_maxclients'      = $Env:TREMULOUS_MAX_PLAYERS
    'timelimit'          = $Env:TREMULOUS_TIME_LIMIT
    'g_suddenDeathTime'  = $Env:TREMULOUS_SUDDEN_DEATH_TIME
    'g_teamForceBalance' = ConvertTo-Bool $Env:TREMULOUS_TEAM_FORCE_BALANCE
    'g_friendlyFire'     = ConvertTo-Bool $Env:TREMULOUS_FRIENDLY_FIRE
    'g_password'         = $(if ($Env:TREMULOUS_PASSWORD) { ConvertTo-Quoted $Env:TREMULOUS_PASSWORD })
    'rconPassword'       = $(if ($Env:TREMULOUS_RCON_PASSWORD) { ConvertTo-Quoted $Env:TREMULOUS_RCON_PASSWORD })
    'sv_pure'            = ConvertTo-Bool $Env:TREMULOUS_PURE
    'sv_allowDownload'   = ConvertTo-Bool $Env:TREMULOUS_ALLOW_DOWNLOAD
    # The engine default is http://downloads.tremulous.net, which a LAN can't reach; empty makes
    # clients download over the game connection instead
    'sv_dlURL'           = $(if ($Env:TREMULOUS_DOWNLOAD_URL) { ConvertTo-Quoted $Env:TREMULOUS_DOWNLOAD_URL.TrimEnd('/') } else { '""' })
}

$maps = @($Env:TREMULOUS_MAP_LIST -split '[\s,;]+' | Where-Object { $_ })
$start = $Env:TREMULOUS_MAP
if (-not $start -and $maps) { $start = $maps[0] }

New-Item -ItemType Directory -Path $dir -Force | Out-Null

# Map rotation. The game plays the rotation from its first entry once the start map ends, so the
# entries after the start map come first and the start map comes last
$rotationFile = Join-Path $dir 'maprotation.cfg'
if ($maps) {
    if ((Test-Path -Path $rotationFile) -and -not ((Get-Content -Path $rotationFile -TotalCount 1) -eq $header)) {
        Move-Item -Force -Path $rotationFile -Destination "$rotationFile.bak"
        Write-Log -Level Warning "TREMULOUS_MAP_LIST is set; moved the existing maprotation.cfg to maprotation.cfg.bak"
    }

    $index = [array]::IndexOf([string[]]($maps | ForEach-Object { $_.ToLowerInvariant() }), $start.ToLowerInvariant())
    $order = if ($index -ge 0) {
        for ($i = 1; $i -le $maps.Count; $i++) { $maps[($index + $i) % $maps.Count] }
    } else { $maps }

    $rotation = @($header, 'lancommander', '{') + ($order | ForEach-Object { "  $_" }) + @('}')
    [System.IO.File]::WriteAllText($rotationFile, ($rotation -join "`n") + "`n")
    chown "$($Env:UID):$($Env:GID)" $rotationFile
    Write-Log "Map rotation: $start, then $($order -join ', ')"
}

$lines = @("$header, edit server.cfg instead")

$serverCfg = Join-Path $dir 'server.cfg'
$hasServerCfg = Test-Path -Path $serverCfg

if ($hasServerCfg -and $start) { $lines += 'exec server.cfg' }

# Read-only on the command line, and the launcher sets them there; here they're informational
$lines += "// dedicated, net_port and net_alternateProtocols are set by tremulous-server"

foreach ($key in $values.Keys) {
    if ($null -ne $values[$key] -and $values[$key] -ne '') { $lines += "set $key $($values[$key])" }
}

if ($maps) { $lines += 'set g_initialMapRotation lancommander' }

if ($start) {
    $lines += "map $start"
} elseif ($hasServerCfg) {
    $lines += 'exec server.cfg'
} else {
    Write-Log -Level Warning "TREMULOUS_MAP and TREMULOUS_MAP_LIST are empty and there is no $game/server.cfg, so no map will be started"
}

[System.IO.File]::WriteAllText($file, ($lines -join "`n") + "`n")
# Not -R: a recursive chown through Merged/ would copy every pk3 up into Overlay/
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Wrote TREMULOUS_* settings to $file"
