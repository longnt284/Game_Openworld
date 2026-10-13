param([switch]$WithStudioReference)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'dependencies.json') | ConvertFrom-Json
$engineDir = Join-Path $projectRoot '.tools/godot'
$engineName = 'Godot_v' + $manifest.godot.version + '_win64_console.exe'
$enginePath = Join-Path $engineDir $engineName
New-Item -ItemType Directory -Force -Path $engineDir | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $engineDir '_sc_') | Out-Null
if (-not (Test-Path -LiteralPath $enginePath)) {
    $archivePath = Join-Path $engineDir $manifest.godot.windows_archive
    $downloadUrl = 'https://github.com/godotengine/godot/releases/download/' + $manifest.godot.version + '/' + $manifest.godot.windows_archive
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $manifest.godot.sha256) { throw 'Godot archive checksum mismatch.' }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $engineDir -Force
    Remove-Item -LiteralPath $archivePath
}
& $enginePath --version
if ($LASTEXITCODE -ne 0) { throw 'Godot could not start.' }
if ($WithStudioReference) {
    $referenceDir = Join-Path $projectRoot '.cache/studio-reference'
    if (-not (Test-Path -LiteralPath $referenceDir)) {
        git clone --depth 1 $manifest.studio_reference.repository $referenceDir
        if ($LASTEXITCODE -ne 0) { throw 'Could not clone studio reference.' }
    }
    if ($manifest.studio_reference.revision -ne 'pending-initial-sync') {
        git -C $referenceDir fetch --depth 1 origin $manifest.studio_reference.revision
        if ($LASTEXITCODE -ne 0) { throw 'Could not fetch pinned studio reference.' }
        git -C $referenceDir checkout --detach $manifest.studio_reference.revision
        if ($LASTEXITCODE -ne 0) { throw 'Could not select pinned studio reference.' }
    }
    Write-Output ('Reference only (no hooks installed): ' + $referenceDir)
}
Write-Output ('Godot ready: ' + $enginePath)
