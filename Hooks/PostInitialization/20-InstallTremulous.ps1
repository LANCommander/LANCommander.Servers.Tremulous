#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install Tremulous from TREMULOUS_SERVER_URL (a .zip with tremded and gpp/data-*.pk3, at its root
# or in one subfolder) into Server/. Reinstalls when TREMULOUS_SERVER_URL changes; the URL of the
# installed package is kept in Server/.tremulous-server-url. The client, renderers, updater and
# Windows files are left out. Files already in Server/ are overwritten by the package, so put your
# own server.cfg, maprotation.cfg, maps and mods in Overlay/.

Invoke-Hook "PreInstallTremulous"

$exe    = Join-Path $Env:SERVER_DIR 'tremded'
$gpp    = Join-Path $Env:SERVER_DIR 'gpp'
$marker = Join-Path $Env:SERVER_DIR '.tremulous-server-url'
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }
$hasData = (Test-Path -Path $gpp) -and (Get-ChildItem -Path $gpp -Filter 'data-*.pk3' -File -ErrorAction SilentlyContinue)

if ((Test-Path -Path $exe) -and $hasData -and (-not $Env:TREMULOUS_SERVER_URL -or $installed -eq $Env:TREMULOUS_SERVER_URL -or -not $installed)) {
    Write-Log "Tremulous found in $Env:SERVER_DIR"
} elseif (-not $Env:TREMULOUS_SERVER_URL) {
    Write-Log -Level Error "tremded or gpp/data-*.pk3 not found in $Env:SERVER_DIR and TREMULOUS_SERVER_URL is empty"
} else {
    Write-Log "Downloading Tremulous from $Env:TREMULOUS_SERVER_URL"

    $file    = '/tmp/tremulous.zip'
    $extract = '/tmp/tremulous'

    curl -fsSL --retry 3 --output $file "$Env:TREMULOUS_SERVER_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:TREMULOUS_SERVER_URL" }

    if ($Env:TREMULOUS_SERVER_SHA256) {
        $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
        if ($hash -ne $Env:TREMULOUS_SERVER_SHA256) {
            Remove-Item -Force -Path $file
            throw "SHA256 mismatch for $Env:TREMULOUS_SERVER_URL`: got $hash, expected $Env:TREMULOUS_SERVER_SHA256 (clear TREMULOUS_SERVER_SHA256 when installing from another zip)"
        }
    }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    # The client, its renderers and client-side game modules, the granger updater and Windows
    # binaries aren't needed by the server
    unzip -q -o $file -d $extract -x '*.exe' '*.dll' 'tremulous' '*/tremulous' 'granger' '*/granger' `
        '*renderer_opengl*' '*gpp/cgame.so' '*gpp/ui.so'
    if ($LASTEXITCODE -gt 1) { throw "Could not extract $file" }

    $root = Get-ChildItem -Path $extract -Filter 'tremded' -Recurse -File -Depth 2 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "tremded not found in $Env:TREMULOUS_SERVER_URL" }
    if (-not (Get-ChildItem -Path (Join-Path $root.FullName 'gpp') -Filter 'data-*.pk3' -File -ErrorAction SilentlyContinue)) {
        throw "gpp/data-*.pk3 not found next to tremded in $Env:TREMULOUS_SERVER_URL"
    }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$($root.FullName)/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy Tremulous into $Env:SERVER_DIR" }

    Remove-Item -Recurse -Force -Path $file, $extract

    # Zip entries can carry odd Unix modes (LANCommander archives carry none); make the data
    # readable and the server executable
    chmod -R u+rwX,go+rX $Env:SERVER_DIR
    chmod +x $exe
    Set-Content -Path $marker -Value $Env:TREMULOUS_SERVER_URL
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Tremulous installed into $Env:SERVER_DIR"
}

Invoke-Hook "PostInstallTremulous"

Set-Location $Env:SERVER_ROOT
