param([ValidateSet('game', 'editor', 'test')][string]$Mode = 'game', [string]$GodotPath)
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
    & $GodotPath --headless --render-thread safe --path $projectRoot --script res://tests/smoke_test.gd
    if ($LASTEXITCODE -ne 0) { throw 'Smoke tests failed.' }
} elseif ($Mode -eq 'editor') {
    & $GodotPath --path $projectRoot --editor
} else {
    & $GodotPath --path $projectRoot
}
