# Asset Pack Version Notes

Tiny Swords is the target visual pack for the final art pass:

- Source: https://pixelfrog-assets.itch.io/tiny-swords
- Required by TZ_RTS_v0.3.1 section 12.1.
- The raw Tiny Swords archive is not bundled in this repository because the TZ explicitly forbids republishing the asset pack as standalone files.

Current build status:

- Runtime uses `config/assets_manifest.json`.
- Missing external art falls back to generated/internal primitive visuals declared in the manifest.
- Before commercial/public asset-complete release, place the customer-provided Tiny Swords source under `assets/_source/`, import derived in-game files under `assets/tiny_swords/`, and update this file with the exact download date/version and license snapshot.
