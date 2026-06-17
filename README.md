# Project Stronghold

RTS prototype for version 0.1, based on `TZ_RTS_v0.3.1.md`.

## Current Scope

- Playable Windows RTS prototype against AI.
- Deterministic fixed-tick simulation, command log, binary snapshots, CI tests.
- Economy: wood, stone, food, gathering, passive farms, construction, production, starvation, unit limit.
- Combat: warriors, towers, attack-move, stances, target acquisition, victory condition.
- Platoons: form/disband, formation movement, broken/regroup feedback.
- Fog of war, known building ghosts, minimap, warnings, result screen, minimal audio feedback.
- Windows portable export and Inno Setup installer.

## Assets

The renderer loads visual fallback data from `config/assets_manifest.json`. Tiny Swords is the intended final art pack, but raw pack files are not committed because the TZ forbids redistributing the pack as standalone assets. See `assets/licenses/PACK_VERSION.md`.

## Local Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate_structure.ps1
godot --headless --script tests/determinism_test.gd
godot --headless --export-release "Windows Desktop"
```

`sim/` must not depend on `game/`.
