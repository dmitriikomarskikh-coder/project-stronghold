# Project Stronghold

RTS prototype for version 0.1, based on `TZ_RTS_v0.3.1.md`.

## Stage 1 Scope

- Godot 4.6.3 project skeleton with Compatibility renderer.
- Fixed-tick simulation scaffold.
- Command schema and deterministic command ordering.
- JSON map loading.
- Camera and tile rendering in full-visibility debug mode.
- Headless determinism smoke test.
- CI workflow for tests and Windows export.

## Local Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate_structure.ps1
godot --headless --script tests/determinism_test.gd
godot --headless --export-release "Windows Desktop"
```

`sim/` must not depend on `game/`.
