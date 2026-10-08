# HOTSHOT CALIFORNIA — handoff for Claude

Updated: 2026-10-05

## Project and absolute paths

- Working repository: `C:/Users/gil_n/Documents/GitHub/Godot-game-development-codex`
- Branch: `codex/continue-polish`
- Main scene: `res://scenes/boot.tscn`
- Godot GUI: `C:/Users/gil_n/OneDrive/Ambiente de Trabalho/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`
- Godot console: `C:/Users/gil_n/OneDrive/Ambiente de Trabalho/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- Previous Claude handoff: `C:/Users/gil_n/Documents/GitHub/Godot-game-development/HANDOFF_CHATGPT.md`
- Review staging root: `C:/tmp_shots/`
- PixelLab key: `C:/Users/gil_n/.pixellab_key` — use without printing or committing it.

Preserve the dirty working tree. It contains valid Claude and Codex work. Inspect changes first; do not reset, clean or overwrite unrelated files.

## User direction

Continue autonomously and improve the whole game. Do not generate an EXE. Keep trailer work paused. The quality target is dense, coherent top-down pixel art based on the supplied references and videos: readable characters and props, detailed environments, strong lighting, nearest-neighbour 4K scaling, and cutscenes with character movement rather than still images. Preserve fast top-down gameplay and clear combat routes.

The user wants at least 200 well-placed decorative props, all approved PixelLab work integrated, improved masks for menu and gameplay, clear animated cutscenes, and less repetitive menu music.

## Critical correction — rejected human batch

The latest human PixelLab batch is rejected and was removed from runtime. The screenshots showed hidden/missing faces, heads viewed vertically from above, near-frontal torsos, incomplete limbs and inconsistent corpse perspective.

Rejected identities: `guard`, `security`, `civilian`, `gunner`, `heavy`, `hunter`, and `riot`, alive and dead.

All 14 PNGs and 14 imports were moved to `C:/tmp_shots/rejected_overhead_batch/`. Do not promote them. With these overrides absent, the game falls back to its previous v4/baked characters.

The replacement direction is top-down oblique, not a strict 90-degree ceiling view. Keep the face partly readable and put head, torso, arms, legs, gear and weapon at one consistent angle. Generate one complete alive/dead guard pair, inspect it in a gameplay capture, and only then consider a batch. Preserve established designs. Saint must retain the hockey mask, broken halo, red mark and white bow.

`tools/art/pixellab_redo.py` still contains the rejected seven-character jobs as an audit trail, but generation/application of human jobs is now locked. Their prompts and outputs are obsolete.

The corrected proof workflow is `tools/art/pixellab_character_proof.py`. Review files are in `C:/tmp_shots/character_oblique_proof/`. The unguided and runtime-guided live/dead attempts are rejected. `guard_alive_imagegen_guided.png` is the first visually coherent candidate: complete anatomy, partly readable face and consistent oblique camera. It is deliberately not integrated because the current non-Cass NPC renderer composes separate torso, legs, live arms and weapon layers. A full-body image would duplicate limbs and break aim/walk animation. Either adapt the candidate into compatible layer art or extend the full-body `CastSprite` path with a real animation set; do not insert the still as `body_guard.png`.

## Current state

- `assets/art/pixellab_world/`: 479 PNGs.
- Audit baseline: 217 world sprites and 300 decor entries across four levels.
- `assets/art/pixellab_ui_v3_approved/`: 181 approved UI/cutscene PNGs.
- Narrative baseline: 91 used dialogue/intro shots have approved PixelLab images; `static` is intentionally engine-generated.
- `assets/art/pixellab_cast_v3_approved/`: 8 PNGs only — four dogs and four fallen poses.
- `assets/art/pixellab_cast_v4/`: current approved Cass clips.
- Levels: `m01_sunset_palms`, `m02_yermo_salvage`, `m03_khsc_studios`, `m04_villa_estrella`.
- Full asset ledger: `C:/Users/gil_n/Documents/GitHub/Godot-game-development-codex/docs/pixellab_integration_audit.md`.

## Implemented work

- VCR text overflow fixed and clock changed to current system time in `scripts/ui/vcr_screen.gd`.
- Menu music replaced through `music/st_menu_tapes.mp3`, `music/source/menu_tapes.mp3`, `data/music.json`, `music/source/songs.json`, and `tools/audio/soundtrack.json`.
- `scripts/systems/sprite_forge.gd` supports approved authored body/corpse overrides when present.
- `tools/cast_preview.gd` supports `CAST_LOOK`, `CAST_POSE=armed`, and `CAST_CORPSE=1` previews.
- `tools/visual_quality_audit.py` audits imports, alpha, oversized assets and narrative coverage.

## Approved staging, not integrated

- `C:/tmp_shots/utility_kit/utility_control_panel.png`

The utility panel remains staging-only because Yermo already has a clearer top-down control-box asset.

## Newly integrated and visually checked

- PixelLab fuse-box on/off states are active in `BreakableProp`; logic and collision are unchanged. Runtime preview: `C:/tmp_shots/utility_kit/fuse_runtime_preview.png`.
- Corrected orthographic kennel cage, dog bed and bowls are active through `Furniture` and `RoomKitsMore`.
- `table_kennel.png` replaces Yermo's repeated turquoise cafe-table texture with a recognisable metal feed-preparation worktable. Runtime capture: `C:/tmp_shots/kennel_kit/m02_kennel_runtime_after.png`.

## Other staging and incompatibilities

- `C:/tmp_shots/redo/`: review redraws; dogs approved, furniture and pickups pending.
- `C:/tmp_shots/masks_world/`: 11 high-resolution masks. Menu concepts are useful and Saint is corrected, but frontal masks are invalid as top-down gameplay overlays.
- `assets/art/pixellab_level_density_review/`: mixed candidates; several are ambiguous, frontal, isometric or noisy.
- Regenerated `motel_power_siphon` and `studio_dust_beam` are rejected.
- `assets/art/pixellab_world/sprites_hq/cage.review.png` is review-only.

## Next actions

1. Run Godot import and audits after the human rollback; confirm previous fallbacks display.
2. Continue the character proof from `guard_alive_imagegen_guided.png`: choose a compatible layered-rig or animated full-body implementation, produce the matching dead pose, and validate the pair in gameplay before batching.
3. Finish a proper top-down kennel cage and validate the full composition.
4. Validate the utility kit in its actual scene, then integrate if scale, alpha and states read correctly.
5. Review density candidates and place only semantically correct props without harming navigation.
6. Review every intro/cutscene image at 4K for a clear subject and action; add layered character motion where still.
7. Create separate frontal menu masks and top-down gameplay masks.
8. Playtest objectives, triggers, doors, combat, deaths and transitions in all four levels.

## Validation

Run from the repository root:

```powershell
python tools/visual_quality_audit.py
python tools/audio_reference_audit.py
python tools/polish_layouts.py --check
& 'C:/Users/gil_n/OneDrive/Ambiente de Trabalho/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --editor --headless --quit-after 3
```

Expected baseline: 217 world sprites, 300 decor entries, 91 used PixelLab narrative shots, zero missing shots/imports/audio, zero empty-alpha or oversized assets, and four reachable layouts.

## Rules

Inspect every generated image before integration. A generated file is not implemented merely because it exists. Validate one example in gameplay before bulk generation. Preserve objectives, triggers, transitions, collision and combat logic. Keep Cass v4 protected. Never force art into the wrong semantic role or camera perspective. Never reuse the rejected overhead humans. Do not generate an EXE or resume the trailer. Report progress as **Agora → Concluído → A seguir** and say whether visuals were actually inspected.
- Hardened `tools/fuse_preview.gd` so headless validation skips viewport capture cleanly instead of calling `save_png` on a null texture. The fuse preview now exits without script errors in headless mode; visual capture remains available in a real renderer.
- Hardened the kennel and cast smoke preview tools against headless viewport captures. They now skip image export with a warning instead of throwing null-texture script errors; real renderer captures remain unchanged.
- Hardened `tools/cast_ingame.gd`, `tools/decor_audit.gd`, `tools/roll_capture.gd`, `tools/boss_capture.gd`, `tools/fire_capture.gd`, and the default gallery path in `tools/cast_preview.gd` against headless viewport captures. Each now exits cleanly with an explicit warning when no visual texture exists.
- Verified the full smoke test at `res://tools/smoke_test.tscn` with `0 failures`, M03 and M04 chapter tests with `0 failures`, and the visual/audio/layout/M01 layer audits after these QA-only changes.
- Verified the M01 gallery in headless review mode with `GALLERY_PRERENDER_GROUND_NO_POOL=1` and `GALLERY_CLEAN=1`; it exits cleanly and keeps the approved ground selection isolated to the review/runtime path.
- Verified the isolated M02 smoke path, the full narrative story path, arcade waves, and all eight weather presets; each completed with `0 failures`.
- Visually inspected `C:/tmp_shots/utility_kit/utility_control_panel.png` and its contact sheet. It is a clean frontal wall panel, while the M02 runtime prop is the distinct `yard_utility_control_box`; kept the candidate staging-only to avoid a semantic/scale mismatch.
- M01 visual scope is now explicitly map-wide: the Godot layout is 68x61 cells with 123 decor entries, and the Blender composition must cover exterior courtyard, motel wings, parking, pool, interiors and transitions while preserving the Godot collision/objective/navigation layout.
## M01 Blender expansion
- Added staging generator: `tools/art/build_m01_interiors.py`.
- Outputs: `assets/art/prerendered/m01_sunset_palms/staging/m01_interiors_transitions_staging.blend` and `m01_interiors_transitions_staging.png`.
- Covers the JSON zone contract: north guest wing, west service transition, reception core, ground-floor guest wing, and a connective corridor.
- This is a layout/material blockout for scale and navigation validation. It is not integrated into Godot runtime yet; the approved runtime remains the low-alpha ground plate while the exterior courtyard Blender scene is reviewed.
- Next step: increase interior prop density/material detail, render each zone at the same camera treatment as the courtyard, compare against the 68x61 gameplay grid, then integrate only after visual + gameplay QA.

- Added persistent visual contract: assets/art/prerendered/m01_sunset_palms/ART_DIRECTION.md. It records the Witchbrook-level detail bar and rejects blockouts as final art.

- Added M01 reception close-up staging render: assets/art/prerendered/m01_sunset_palms/staging/m01_reception_detail_staging.png. It is a proof pass for 3/4 readability; still staging and not runtime-integrated.

- Added audit tool 	ools/art/audit_m01_staging.py; it confirms exterior/interior Blender staging files exist and image outputs meet minimum resolution without promoting them to runtime.

- Added M01 staging status and promotion gates: assets/art/prerendered/m01_sunset_palms/STAGING_STATUS.md.

- Blender M01 staging received a procedural surface variation pass for wall/floor/wood/metal/tile materials; regenerated full and reception-detail renders.

- Added guest-room narrative prop pass to M01 Blender staging: rug, suitcase, nightstand/lamp and desk details; regenerated staging renders.

- Added room identity pass to M01 Blender interiors: signage/number plaques and framed wall anchors; regenerated staging outputs.

- Added non-runtime pixel treatment preview tool tools/art/pixelize_m01_staging.py; outputs pixel previews from Blender staging only.

- M01 staging audit now includes both pixel preview derivatives and verifies their resolution.

- Added runtime isolation gate 	ools/art/audit_m01_runtime_isolation.py; staging Blender and pixel-preview names must not appear in runtime sources.

- Updated STAGING_STATUS.md with the latest visual/audio/layout/gameplay/runtime-isolation verification snapshot.

- Recorded successful Godot reimport of all four M01 staging PNG outputs in STAGING_STATUS.md.

- Added M01 asset provenance manifest: assets/art/prerendered/m01_sunset_palms/ASSET_PROVENANCE.md, documenting Meshy sources versus Blender-authored environment and integration rules.

- Added service-transition detail render to the M01 staging audit and regenerated it from Blender.

- Added pixel preview and audit coverage for M01 service-transition detail render.

- Recorded M01 Blender staging object count (140 total, 80 props/detail) in STAGING_STATUS.md.

- Recorded successful Blender staging load validation (140 objects, 10 materials).

- Added M01 pixel-preview contact sheet: assets/art/prerendered/m01_sunset_palms/staging/m01_pixel_previews_contact.png.

- User supplied a higher-detail Sunset Palms reference image; appended its concrete quality bar to ART_DIRECTION.md. Current M01 remains partially complete/staging, not represented as final quality yet.

- Recorded exterior courtyard Blender inspection (142 objects, 56 materials, 78 lights).

- Recorded per-level/area adaptation rule in ART_DIRECTION.md: shared density/camera quality, distinct authored dressing for M01-M04.

- Added cross-level coherence rules to ART_DIRECTION.md: shared camera, scale, lighting grammar, density and gameplay readability with per-level authored identity.

- Verified trailer/export guard for current art pass; no trailer capture or EXE generation performed.

- Added runtime ambient animation for M01 pool floats (motel_pool_float/motel_pool_float_flamingo) using new scripts/levels/animated_prop.gd; pool water already uses PoolFX wave motion.

### Ambient level animation update (2026-10-05)
- Verified `scripts/levels/decor.gd` now attaches `res://scripts/levels/animated_prop.gd` to M01 `motel_pool_float` and `motel_pool_float_flamingo` only; they bob and sway without changing collision/gameplay.
- Existing PoolFX water shaderless draw loop continues to animate slow surface ripples; palm sway and light flicker remain active.
- Godot 4.7.2 headless editor import completed successfully after the change. Full smoke was started and reached the M01 boss-phase checks; rerun the complete smoke before any promotion.
- Trailer remains paused; no EXE generated.
- Pool floats now also drift horizontally by 1.6 px at a slower phase, preserving their base positions and gameplay collision-free behavior.
- Full Godot smoke rerun after fixing AnimatedProp indentation: `=== SMOKE TEST DONE: 0 failures ===` for M01 + M02.
- Added opt-in 4K Blender layer export: set M01_RENDER_4K=1 when running tools/art/render_motel_layers.py; output goes to assets/art/prerendered/m01_sunset_palms/layers/4k/ and cannot overwrite the validated 1920x1080 runtime layers.
