Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$required = @(
    "project.godot",
    "export_presets.cfg",
    "sim/tick.gd",
    "sim/commands.gd",
    "sim/map.gd",
    "sim/snapshot.gd",
    "game/main.tscn",
    "game/main.gd",
    "config/balance.json",
    "config/assets_manifest.json",
    "maps/map01.json",
    "tests/determinism_test.gd",
    "tests/main_scene_smoke_test.gd",
    ".github/workflows/ci.yml"
)

foreach ($path in $required) {
    $full = Join-Path $root $path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing required file: $path"
    }
}

Get-ChildItem -LiteralPath (Join-Path $root "config") -Filter "*.json" -File | ForEach-Object {
    $null = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
}
$null = Get-Content -LiteralPath (Join-Path $root "maps/map01.json") -Raw | ConvertFrom-Json

$simImportsGame = Get-ChildItem -LiteralPath (Join-Path $root "sim") -Filter "*.gd" -File -Recurse |
    Select-String -Pattern "res://game/" -SimpleMatch
if ($simImportsGame) {
    throw "sim/ must not import game/: $($simImportsGame.Path)"
}

Write-Host "Project structure validation passed."
