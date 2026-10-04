# HOTSHOT CALIFORNIA — Claude handoff

## Project

- Godot 4.7.2 project: `C:/Users/gil_n/Documents/GitHub/Godot-game-development-codex`
- Main scene: `res://scenes/boot.tscn`
- Godot headless parse check currently passes.

## Artistic direction

The target is premium, dense pixel art inspired by the supplied references and video: readable silhouettes, distinct materials, warm/cool lighting contrast, lived-in interiors, detailed exteriors, deliberate prop clusters, and cinematic animation. The game remains top-down and fast like Hotline Miami; the references are a density and finish target, not a camera conversion to isometric.

Use nearest-neighbour scaling for 4K/widescreen. Keep combat lanes, doors, windows, objectives, and escape loops clear. Every room should have a visual anchor, a functional obstacle, and 2–4 story props.

## Current implementation

- Four validated levels: `m01_sunset_palms`, `m02_yermo_salvage`, `m03_khsc_studios`, `m04_villa_estrella`.
- 300 decorative plan entries distributed across the four maps (73/86/71/70).
- 195 PixelLab sprites in `assets/art/pixellab_world/sprites`.
- PixelLab character torso work exists in `assets/art/pixellab_cast_v4` for Cass, guard, civilian, and welder.
- PixelLab boss assets exist for Dutch/Fireman and Harcourt.
- Gore was cleaned: decorative bone piles removed; corpses use authored final-death sprites; combat gore remains limited and contextual.
- `scripts/levels/dressing.gd` maps common clutter to PixelLab sprites.
- `scripts/narrative/cutscene.gd` applies slow camera drift, breathing light, and readable motion to full-frame art.
- `StoryShot` supports parallax, breathing, blinking, smoke, fire, rain, scanlines, camera movement and other layered animation.
- 79 dialogue shots are resolved with zero missing shots according to `tools/visual_quality_audit.py`.
- Music: 62 OGG tracks and 205 WAV SFX; `tools/audio_reference_audit.py` reports 38 music references and zero missing files. Do not generate new music unless a concrete gap is found.
- Trailer is intentionally paused. Existing MP4 captures may need rebuilding later.

## Validation commands

Run from the project root:

```powershell
python tools/visual_quality_audit.py
python tools/audio_reference_audit.py
python tools/polish_layouts.py --check
& 'C:\Users\gil_n\OneDrive\Ambiente de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . --editor --headless --quit-after 3
```

Expected: 195+ sprites, 300 decor entries, zero missing imports/alpha/shots, zero missing audio references, all four maps reachable.

## PixelLab generation

- Local token is stored in `~/.pixellab_key`; never print it.
- Reusable generator: `tools/art/generate_context_clutter.py <manifest.json>`.
- Manifests are in `tools/art/` and generated review sheets live under `assets/art/Artwork/`.
- Review PNGs visually before promoting them to `assets/art/pixellab_world/sprites`.
- Native assets are generally 32×32 or 64×64; scale with nearest filtering for 4K.

## Important files

- `docs/visual-quality-target.md` — art direction and acceptance checklist.
- `docs/pixel-lab-level-blueprint.md` — level atmosphere, environmental storytelling, asset categories and combat flow.
- `tools/expand_decor.py` — deterministic density expansion for level decor.
- `tools/visual_quality_audit.py` — sprite/import/cutscene audit.
- `tools/audio_reference_audit.py` — music path audit.
- `scripts/player/character_visual.gd` — player rig, weapon grip and scale.
- `scripts/systems/sprite_forge.gd` — authored torso/corpse selection.
- `scripts/levels/dressing.gd` — procedural room clutter and PixelLab mapping.
- `scripts/narrative/story_shot.gd` — animated cutscene shot registry.

## Remaining work

1. Finish reviewing the intro/cutscene fallbacks that still use older painted art. Prioritize `mom_kitchen`, `phone_cass`, `lobby_phone`, `yermo_office`, `tv_mansion`, and `casting_1990`; generated PixelLab candidates are being staged under `assets/art/Artwork/pixellab_intro_refresh/`.
2. Keep all cutscene frames readable: one clear focal subject, recognisable silhouettes, contrast, and nearest scaling up to 4K.
3. Perform manual visual review in the Godot editor for all four levels and the intro.
4. Rebuild the trailer only when requested; it is not part of the current validation gate.

## Working rules

- Preserve objective nodes, triggers, scene transitions, and combat logic.
- Do not force a semantically wrong sprite just to eliminate procedural drawing.
- Show progress as: **Agora → Concluído → A seguir**.
- Be explicit when a result is not visually inspected or when an external generation endpoint is unavailable.
