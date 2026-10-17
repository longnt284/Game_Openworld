param([ValidateSet('game', 'editor', 'test', 'preview', 'export')][string]$Mode = 'game', [string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'dependencies.json') | ConvertFrom-Json
    $GodotPath = Join-Path $projectRoot ('.tools/godot/Godot_v' + $manifest.godot.version + '_win64_console.exe')
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Run tools/setup.ps1 first or pass -GodotPath.' }
if ($Mode -eq 'test') {
    & $GodotPath --headless --path $projectRoot --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Asset import failed.' }
    foreach ($suite in @('smoke_test', 'gameplay_test', 'combat_test', 'progression_test')) {
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot ('tests/' + $suite + '.gd')))) { continue }
        & $GodotPath --headless --render-thread safe --path $projectRoot --script ('res://tests/' + $suite + '.gd')
        if ($LASTEXITCODE -ne 0) { throw ($suite + ' failed.') }
    }
} elseif ($Mode -eq 'preview') {
    & $GodotPath --path $projectRoot --resolution 1920x1080 --script res://tests/render_preview.gd
} elseif ($Mode -eq 'export') {
    $output = Join-Path $projectRoot 'build/windows'
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    & $GodotPath --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $output 'VanKhe.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Export failed. Run tools/setup.ps1 -WithExportTemplates first.' }
} elseif ($Mode -eq 'editor') {
    & $GodotPath --path $projectRoot --editor
} else {
    & $GodotPath --path $projectRoot
}
