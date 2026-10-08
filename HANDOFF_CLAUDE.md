# Claude handoff — HOTSHOT California

Updated: 2026-10-05 (Europe/Lisbon)

## Work location

Continue in this exact repository/worktree:

`C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex`

Current branch:

`codex/continue-polish`

The checkout is intentionally dirty and contains valuable work from Codex and Claude. Do not reset, clean, checkout over, or discard unrelated changes. Inspect `git status` before editing.

Godot console executable:

`C:\Users\gil_n\OneDrive\Ambiente de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

PixelLab key file (read it if an existing project script needs it; never print or commit it):

`C:\Users\gil_n\.pixellab_key`

Review/staging root:

`C:\tmp_shots`

## User requirements

- Polish the entire Godot game to a consistently high visual standard using the supplied pixel-art references and video direction.
- PixelLab artwork must be reviewed for anatomy, perspective, readability, scale, transparency, and runtime compatibility before integration.
- Integrate every approved PixelLab asset into the game; do not integrate rejected or merely generated candidates.
- Cutscenes must be readable, maximum 4K, and visibly animated with character/environment movement rather than plain stills.
- Levels should feel full and visually appealing, with at least 200 well-placed decorative props. The current audit reports 300 decor entries.
- Improve UI, characters, masks, props, music, sounds, level layouts, and gameplay where needed.
- The menu music was replaced because the old track was repetitive.
- Keep the trailer task paused.
- Do not generate an EXE.

## UPDATE 2026-10-05 14:00 (Claude): cast is drawn as REAL-TIME 3D (supersedes baked oblique sprites)

Baked 16-facing sprites cost ~64 MB VRAM per clip (4096² atlas) → >1 GB per character.
So the game now draws the 3D model live: `scripts/player/cast_model.gd` (`CastModel`
extends `CastSprite`, same interface). Each character has a 128 px SubViewport with the
fixed 50° ortho camera, its own lights (warm key, cool rim), the GLB's AnimationPlayer,
hips kept over the ground point, grips from the hand bones, a 1-texel outline shader that
keeps the node modulate (level actor boost + hit flash), and no rendering when off screen.
`CastModel.create(look)` picks real-time GLB → baked clips → null (2D rig fallback);
`CAST_BAKED=1` forces the baked sprites for comparison.

Building a character's GLB (Blender does the animation direction):
`blender -b --python tools/art/render_cast3d.py -- assets/art/Artwork/3d/<id> C:\tmp_shots\bake_tmp\<id> --fps 15 --bake assets/art/cast3d_rt/<id>/<id>.glb`
→ every game clip (incl. armed_*, reload_*, punch(_left), melee, aim_melee, smoke) with the
grip IK baked onto the repaired rig. Raw Meshy clips are NOT usable directly: Cass's raw
idle/aim/walk throw the arms over the head. (`tools/art/build_cast_glb.py` merges raw clips
only — kept for reference, don't ship its output.)

Status: Cass + guard GLBs baked; both use CastModel in game. `assets/art/cast3d/guard/`
(baked sprite atlases from the earlier test) can be deleted once real-time is approved.

## UPDATE 2026-10-05 12:55 (Claude): NEW CHARACTER DIRECTION — oblique 3D cast (supersedes the top-down plan below)

The user wants characters to look like their painted reference (full body, ~50° high
oblique, detailed: `assets/art/Artwork/3d/guard/reference.png`), scaled into the game.
User instructions: use Blender (installed: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`)
for anything that improves the game, including art direction; characters FIRST, then
levels at the quality of the user's reference images (ask the user to re-send them: they
are not stored anywhere on disk), animate things, add detail/art/assets.

Pipeline (guard is the pilot):
1. `python tools/art/meshy3d.py image <id>` — Meshy image-to-3D from `characters3d.json`
   `"image"` (new command); then `rig <id>` and `anim <id> idle walk run aim melee punch death death_back knocked`.
   Guard done: 62 credits (946 left).
2. Blender: `blender -b --python tools/art/render_cast3d.py -- assets/art/Artwork/3d/<id> C:\tmp_shots\oblique_blender\<id> --size 256 --meters 2.56 --fps 12 --elev 50 --dirs 16`
   (new `--elev/--dirs` oblique mode: fixed camera, figure turned to 16 facings, IK grips
   turned with the facing, hands stored as screen pixels from the ground point).
3. `python tools/art/pack_cast3d.py <id> --px 128 --src C:\tmp_shots\oblique_blender\<id>`
   → `assets/art/cast3d/<id>/` (facings as row blocks, meta has directions/origin).
4. Runtime: `CharacterVisual.setup` uses `CastSprite` for ANY look with
   `assets/art/cast3d/<look>/meta.json`; oblique clips stay upright, pick the facing from the
   rig angle, convert hands into rig space; weapon drawn under the body when facing away.
   Missing clips fall back (armed_dual_walk → armed_walk → walk; aim_melee → aim).
   Downed enemies hold the `knocked` clip until `recover()`. `Corpse` plays the rendered
   `death` (oblique: facing the shooter) unless a body part is missing.
5. Review at 16 facings + in a level next to Cass before rolling out to other looks.
   Cass is still top-down: she must be re-rendered oblique too for consistency
   (her glbs are in `assets/art/Artwork/3d/cass/`).

Level art direction from the user's references is written up in
`docs/visual-quality-target.md` (top section): 3/4 oblique, walls with height, dense
grouped props, warm practicals vs cool shadows, lots of motion. Adapt to 80s California
neon-noir. Levels come AFTER the cast.

Review tool: `tools/cast_lineup.tscn` (CAST_LOOK, CAST_PREVIEW_OUT, CAST_ZOOM,
CAST_MISSION; non-headless): 8 copies around Cass in a real mission + downed + corpse.

`tools/art/render_cast_oblique.gd` (+ .tscn) is a Godot-only quick preview renderer
(no IK); prefer Blender for real output.

## UPDATE 2026-10-05 12:20 (Claude): character torso direction changed

Runtime check of the "corrected" guard (`guard_unarmed_arms_clear_layer`) FAILED: the
rig rotates the whole torso layer with the aim (`scripts/player/character_visual.gd:177`,
`rig.rotation = angle + ...`). The corrected guard is an upright frontal figure, so at
aim 180° he is upside down and at 90°/270° he lies on his side. Evidence:
`C:\tmp_shots\character_pose_proof\rotation_check.png` (top row guard, bottom row Cass).

Root cause of the original "fist on head" complaint: the painted bodies
(`assets/art/cast/body_*.png`, oblique, face toward camera) are pasted over top-down rig
arms, so the arm from the screen-up shoulder crosses the head. The old baked guard
sprites and the HEAD v4 guard poses all have this defect, so reverting does not help.

**User decision:** redo EVERY non-Cass human torso as a strict top-down layer that rotates
with the aim: head seen from above at the center, shoulders above/below, arms pointing
forward (+x), never over the head. Cass is unaffected (full-body `CastSprite` clips).

Tools added for this:
- `SpriteForge.plain_topdown` (static flag in `scripts/systems/sprite_forge.gd`): draws
  the plain top-down rig, ignoring pose art and painted bodies. Tool use only.
- `tools/art/topdown_pose_guides.gd`: writes 60 guides (15 looks × unarmed/aim_one/
  aim_two/melee) to `C:\tmp_shots\topdown_pose_guides\` with the rig's exact hand
  coordinates. Contact sheets `_sheet_a.png` / `_sheet_b.png`.
- `tools/cast_preview.gd`: `CAST_AIM=<degrees>` env var to capture a look at any angle.

### Applied (12:45)
- `SpriteForge.plain_topdown` now defaults to **true** at runtime: every non-Cass human
  torso is the plain top-down rig (palette, hair/cap, extras, rig-exact arms). Painted
  oblique bodies, baked `t_*.png` and all `pixellab_cast_v4/<human>_*.png` layers are
  skipped (kept on disk). Bosses still use `BOSS_ART`. Cass unchanged.
- Runtime proof, 5 looks × aim 0/90/180/270 + armed:
  `C:\tmp_shots\topdown_runtime\_sheet.png`. Hands follow the aim, head stays clear.
- Guard kept on the game palette (teal shirt, navy cap) for consistency with corpses,
  downed sprites and legs.
- Validation after the change: visual audit `sprites=217 decor_entries=300`, all zero
  missing; audio `38/0`; layouts all reachable; `git diff --check` clean; smoke test
  **0 failures**. `compile_all.gd` via `--script` reports 73 "Identifier not found"
  errors that are only the missing autoloads in `--script` mode (not real failures).

### Rejected PixelLab attempt
`tools/art/pixellab_topdown_poses.py` repainting each pose separately (strength
700/400/300/250/150, with guide recolour): low strength drifts per pose (head shape lost,
duplicated badge, ring artefacts), high strength is a copy of the guide. Pose-by-pose
repaint cannot keep one identity across the poses the rig swaps between. Candidates:
`C:\tmp_shots\topdown_pose_pixellab\` (review only, not approved).

### Next art pipeline (recommended)
Generate ONE top-down **body without arms** (head from above + shoulders) per look with
PixelLab, sized like the rig torso, and let the existing hybrid code draw the arms over it,
so every pose shares the same painting. Load it from a new dir (e.g.
`assets/art/pixellab_cast_topdown/body_<look>.png`) that `plain_topdown` does NOT skip;
keep the hybrid's arm-over-painting order so no arm crosses the head. Review each body at
0/90/180/270 + armed + in a level at game scale before integrating.

The autonomous scheduled task `hotshot-autonomous-polish` (every 5 min, lock file
`C:\tmp_shots\autopolish.lock`) continues from this file.

## (Superseded) guard pose correction

The user rejected this generated guard sprite because the upper fist/arm reads as if it is resting on the head:

`C:\Users\gil_n\AppData\Local\Temp\codex-clipboard-a9634c3e-66ec-44f1-a9c4-5140b972fa57.png`

The rejected PixelLab guard pose set was removed from the runtime and preserved here:

`C:\tmp_shots\rejected_guard_arm_head`

The original fallback also inherited a similar high-fist silhouette, so simply reverting was not enough. A corrected anatomy guide was generated with both arms below the chest, converted through PixelLab, and adapted into a 64×64 upper-body layer:

- Guide: `C:\tmp_shots\character_pose_proof\guard_unarmed_arms_clear_guide.png`
- PixelLab full-body proof: `C:\tmp_shots\character_pose_proof\guard_unarmed_arms_clear.png`
- Compatible 64×64 layer: `C:\tmp_shots\character_pose_proof\guard_unarmed_arms_clear_layer.png`
- Runtime destination: `assets/art/pixellab_cast_v4/guard_unarmed.png`

Godot successfully reimported the corrected runtime destination. The next action must be a fresh `CAST_LOOK=guard` runtime capture after that reimport and a visual check. The capture made before the forced `--import` still showed the cached old sprite and is not valid evidence. Do not approve or expand the remaining guard poses until the post-import capture proves the head is unobstructed and the torso aligns with the old leg layer.

The relevant generator is:

`tools/art/pixellab_pose_proof.py`

It is deliberately review-only. The other rejected human batches must not be restored from staging.

## Character generation decisions

The generated human alive/dead overrides for `guard`, `security`, `civilian`, `gunner`, `heavy`, `hunter`, and `riot` were removed after user review. They mixed a ceiling-view head with frontal shoulders, hid faces, or produced busts without readable arms. They are preserved here:

`C:\tmp_shots\rejected_overhead_batch`

Do not promote those files. Approved cast currently contains dogs; humans use the established layered/baked system until a replacement passes review.

Character proof tools and staging:

- `tools/art/pixellab_character_proof.py`
- `tools/art/pixellab_pose_proof.py`
- `C:\tmp_shots\character_oblique_proof`
- `C:\tmp_shots\character_pose_proof`

`guard_alive_imagegen_guided.png` is a coherent full-body study, but cannot be dropped directly into the current non-Cass renderer because the renderer composes torso, legs, arms, and weapon layers. Doing so would duplicate limbs and break animation.

## Integrated world-art corrections

The following PixelLab assets are integrated and validated:

- `assets/art/pixellab_world/sprites_hq/fuse_box_on.png`
- `assets/art/pixellab_world/sprites_hq/fuse_box_off.png`
- `assets/art/pixellab_world/sprites_hq/cage.png`
- `assets/art/pixellab_world/sprites_hq/kennel_dog_bed.png`
- `assets/art/pixellab_world/sprites_hq/kennel_dog_bowl.png`
- `assets/art/pixellab_world/sprites_hq/table_kennel.png`

Related code:

- `scripts/levels/breakable_prop.gd`
- `scripts/levels/room_kits_more.gd`
- `scripts/levels/level_builder.gd`

The ambiguous turquoise rectangles in Yermo were generic café tables. They were replaced with the dedicated metal kennel/feed-prep table. Runtime evidence:

- Before: `C:\tmp_shots\kennel_kit\m02_kennel_runtime.png`
- After: `C:\tmp_shots\kennel_kit\m02_kennel_runtime_after.png`

## Cutscene status

`tools/cutscene_contact_sheet.py` audits the 91 actually referenced cinematic paintings and generated:

`C:\tmp_shots\cutscene_audit\used_shots_01.jpg` through `used_shots_06.jpg`

The intro has 13 unique painted shots. Audit result:

- 13/13 have approved PixelLab files.
- 13/13 have camera motion and local animation zones in `scripts/narrative/story_shot.gd`.
- All are 1920×1080.
- None exceeds 4096 pixels on either dimension.

Most are clear. Continue a targeted review rather than regenerating everything. The strongest known style inconsistency is `vance_boys`, which reads as a daylight photograph among painterly cinematic frames. Other frames worth checking in dialogue context are `d_changeorder` and `dead_line`, whose close compositions may be unclear without the preceding line.

The animation system is in `scripts/narrative/story_shot.gd` and includes pan/zoom, breathing, sway, blink, TV, flicker, heat, sirens, drift, smoke, rain, embers, and other effects. Preserve this system.

## Clock request

The user requested that the VHS time display show the actual local system time. `scripts/ui/vcr_screen.gd` already does this. `scripts/ui/intro.gd`, `scripts/ui/title_screen.gd`, and `scripts/ui/splash_screen.gd` still need the same correction. An attempted multi-file patch failed before applying because the title-screen context differed; redo it carefully per file using `Time.get_time_dict_from_system()` and `%02d:%02d:%02d`.

## Music and audio

The repetitive menu music was replaced. Relevant changed files include:

- `music/source/menu_tapes.mp3`
- `music/st_menu_tapes.mp3`
- `data/music.json`
- `music/source/songs.json`
- `tools/audio/soundtrack.json`

Last audio reference audit: `audio_refs=38 missing=0`.

## Last known validation

Before the latest guard change, these checks passed:

- `python tools/visual_quality_audit.py`
  - `sprites=217 decor_entries=300`
  - `pixel_shots=91 missing_pixel_shots=0`
  - `missing_imports=0 empty_alpha=0 oversized=0 missing_shots=0`
- `python tools/audio_reference_audit.py`
  - `audio_refs=38 missing=0`
- `python tools/polish_layouts.py --check`
  - all four levels reachable; no single-exit rooms
- `git diff --check`
- `res://tools/smoke_test.tscn`
  - zero failures, including missions 1 and 2, dogs, permanent fuse power cut, bosses, objectives, combat, and save/load

After finishing the guard correction, rerun the visual audit, `git diff --check`, Godot import/compile, and the smoke test. Do not create an EXE.

## Commands to resume

Run from the repository root:

```powershell
Set-Location 'C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex'
$godot = 'C:\Users\gil_n\OneDrive\Ambiente de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'

# First: verify the newly imported corrected guard in the real compositor.
$env:CAST_LOOK = 'guard'
$env:CAST_PREVIEW_OUT = 'C:\tmp_shots\character_pose_proof\guard_corrected_runtime_after_import.png'
& $godot --path . res://tools/cast_preview.tscn --display-driver windows --audio-driver Dummy
Remove-Item Env:CAST_LOOK, Env:CAST_PREVIEW_OUT -ErrorAction SilentlyContinue

# Core checks after changes.
python tools/visual_quality_audit.py
python tools/audio_reference_audit.py
python tools/polish_layouts.py --check
git diff --check
& $godot --headless --path . --script tools/compile_all.gd
& $godot --headless --path . res://tools/smoke_test.tscn
```

## Next steps, in order

0. CURRENT QUEUE (2026-10-05 14:30) — supersedes items 1-2c below:
   a00. 16:30 decisions/state:
      - Cass keeps her ORIGINAL Meshy model; only the hair changed (user: "keep the old
        model, just change the hair" to loose wavy auburn as in the cutscenes).
        `tools/art/swap_hair.py` (base rig + donor cass_v2 hair → `Artwork/3d/cass/rig_newhair.glb`),
        baked with `render_cast3d.py --bake ... --mesh rig_newhair.glb`. cass_v2 is only a hair donor.
      - User added Meshy credits (>2800, "use what you need"). Every NPC, boss and animal gets
        the 3D treatment. Batch 1 (12 enemies) + batch 2 (boss fireman buck burnt riot civilian
        zombie ghoul cultist demon) generating; `tools/art/bake_ready_cast.py --loop 120` bakes
        each finished one into `assets/art/cast3d_rt/<id>/<id>.glb`.
      - Dogs: Meshy rigging is humanoid-only → model from Meshy (`humanoid: false` specs),
        quadruped rig + clips authored in Blender (to do: tools/art/rig_quadruped.py), and a
        Dog-side renderer (dogs don't use CharacterVisual).
      - Hero car: user rejected the seated Cass over the top-down car sprite ("lying down",
        "clips through the door"). Fix in progress: 3D Eldorado (`eldorado` spec) in ONE
        viewport with a Cass instance so the body hides her legs; driver door cut out in
        Blender with a hinge; she climbs out in that viewport, then hands over to the player.
        Keep the 66x26 collision footprint.
      - In-game zoom: mouse wheel / +/- (85%-135%), saved as setting `camera_zoom`.
      - CastModel bug fixed: progress-driven clips used speed_scale 0, freezing the blend.
   a0. 15:00: calm idle done — clips in `CALM` (idle, punch(_left), melee, smoke, aim_melee)
      stand on the rig's rest pose with IK arms + spine breath, not Meshy's combat stance;
      `tools/cast_preview.gd` now runs 30 updates before capturing (it used to capture the
      rest pose before the clip applied, which looked like a gun at the hip).
      12 Meshy characters generating (specs in characters3d.json, stop at <260 credits):
      gunner hunter heavy scout bellhop scrapper security stagehand biker sniper handler welder.
      For each finished one: `render_cast3d.py --bake` → `--import` → `cast_lineup.tscn` review.
   a. Cass + guard real-time 3D cast DONE and validated (smoke 0 failures, audits clean).
      Evidence: `C:\tmp_shots\oblique_blender\HOTSHOT_cast3d_ingame.png`, `HOTSHOT_cast3d_angles.png`.
      Known gaps: idle is Meshy's wide combat stance (consider a calmer idle action id);
      armed walk holds the gun at the right hip, slightly outside the silhouette — check
      grip/offset against `_grip_offset`; Cass's corpse/downed paths need an in-game check.
   b. Roll out the cast: one Meshy model per enemy look (gunner, heavy, hunter, riot,
      security, scout, sniper, handler, scrapper, welder, biker, bellhop, stagehand) + civilian
      NPC + bosses. ~62 credits each (text-to-3D 30 + rig 5 + 9 anims 27); keep ≥200 credits
      in reserve, so prioritise the looks used most in missions 1-2 (count `look` in levels/*.json).
      Prompts: write per-look entries in `tools/art/characters3d.json` from `SpriteLib.PALETTES`
      + `SpriteForge.STYLES` (hair, extras, colours) in the same 80s neon-noir style as cass/guard.
      Then `render_cast3d.py --bake`, Godot `--import`, `tools/cast_lineup.tscn` review.
   c. After the cast is approved, delete `assets/art/cast3d/guard/` (baked atlases, test only).
   d. Levels, per `docs/visual-quality-target.md` (user references): walls with height,
      density, warm practicals vs cool shadow, motion. Blender approved for props/set pieces.
1. DONE: guard post-import capture; failed rotation check (see UPDATE above).
2. DONE: all non-Cass humans switched to the plain top-down rig (see UPDATE).
2a. Capture a real level at game scale (enemies in several facings) and confirm the top-down humans read well next to Cass and the props; tune contrast (cap/hair vs shoulders) in `sprite_forge.gd` if needed.
2b. Top-down painted bodies without arms via PixelLab (pipeline above): pilot guard, then the rest; check downed/corpse sprites (`SpriteLib.downed`, `Corpse`) for the same oblique-face problem.
2c. Bosses (`BOSS_ART`: boss_harcourt, boss_dutch, boss_buck): check rotation at 4 angles; same rule applies if they fail.
3. Fix the intro/title/splash VHS clock to use the local system time.
4. Finish the targeted cutscene-context audit and replace only frames proven unclear or stylistically inconsistent; preserve 1920×1080 output and animation definitions.
5. Continue level/UI/character polish and gameplay validation.
6. Update `docs/claude_handoff.md` and `docs/pixellab_integration_audit.md` when decisions change.

Never treat generated output as approved merely because an API call succeeded. Runtime capture and visual review are required.

## Estado verificado 2026-10-05
- Projeto: C:/Users/gil_n/Documents/GitHub/Godot-game-development-codex
- Nível ativo: M01 Sunset Palms; trailer pausado; nenhum EXE gerado.
- Melhor captura ground review: C:/tmp_shots/m01_ground_no_emissive_alpha22.png.
- Comparação: assets/art/prerendered/m01_sunset_palms/ground_review_comparison.png.
- Camada no-emissive: assets/art/prerendered/m01_sunset_palms/layers/ground_no_emissive_review.png (preview-only).
- Gates: layer audit PASS, pixel candidate audit PASS, visual/audio/layout audits PASS, smoke test 0 failures.
- Não integrar full plate; validar primeiro o crop/oclusão com GALLERY_PRERENDER_ISOLATE=1.



## Validação mais recente 2026-10-05
- `python tools/visual_quality_audit.py`: 217 sprites, 300 decor entries, 91/91 pixel shots, 0 missing imports/alpha/oversized/shots.
- M01 Sunset Palms continua como nível ativo e a arte pré-renderizada continua preview-only; não integrar full plate nem a camada combinada antes do gate visual/oclusão.
- Smoke test anterior: 0 falhas em M01/M02. Trailer pausado; nenhum EXE gerado.


## 2026-10-05T21:40:28 — alpha22 capture gate

Reviewed `C:\tmp_shots\m01_ground_no_emissive_alpha22_latest.png` after the latest Godot import. The ground-only preview is correctly aligned and preserves the pool/pavement landmarks, but at the current gallery compositing it is too dark and shows visible chromatic/fringe artifacts around the emissive props. It remains **preview-only** and is rejected for integration until a brighter, cleanly composited capture passes character/objective readability and occlusion review.


## 2026-10-05T21:41:50 — clean preview review mode

Added opt-in `GALLERY_CLEAN=1` handling in `tools/level_gallery.gd`. It hides only the post-process CRT layer and darkness overlay and restores the level ambient modulate for asset review, leaving normal gameplay untouched. This is intended to produce a clean value/occlusion capture before the Sunset Palms plate gate. Godot editor import/parse and `git diff --check` pass.


## 2026-10-05T21:43:49 — clean alpha32 capture review

Generated `C:\tmp_shots\m01_ground_clean_alpha32_v2.png` with `GALLERY_CLEAN=1`. Neutralising the gallery ambient removes the severe black/purple crush and makes pool geometry and pavement seams readable. The capture still contains intentional production weather/lighting and high-contrast live props, so it is suitable for alignment review but not yet sufficient as a final integrated backdrop. Keep the Blender layer preview-only pending a final occlusion/readability pass.


## 2026-10-05T21:45:04 — clean alpha32 v3

Generated `C:\tmp_shots\m01_ground_clean_alpha32_v3.png` with weather hidden in clean review mode. This removes rain noise and confirms the plate alignment/occlusion landmarks, but the production red light pool remains visible by design. The layer is still not promoted to runtime integration; next gate is readability with the intended live player/objectives over this neutral review.


## 2026-10-05T21:46:01 — normal runtime regression check

Ran the normal headless smoke test with no gallery environment overrides. It passed title/cutscene boot, level construction, movement, combat, doors, props, checkpoint/restart, boss breach, phase transition, and Harcourt damage checks before the terminal output window ended. No regression from the opt-in clean gallery mode was observed; full suite marker remains pending a longer capture window.


## 2026-10-05T21:47:52 — live composition gate rejected

Reviewed `C:\tmp_shots\m01_ground_clean_live_alpha22.png` with live art and player visible. The ground plate is aligned, but the combined composition is overexposed and duplicate pool/prop landmarks compete with gameplay silhouettes. This is a useful negative gate: do not integrate the plate into normal runtime yet. Keep the plate isolated/preview-only and resolve lighting/duplicate landmark ownership first.


## 2026-10-05T21:50:09 — no-pool staging export

Added preview-only `layers/ground_no_pool_review.png` from the Blender exporter and an opt-in `GALLERY_PRERENDER_GROUND_NO_POOL=1` selector. The live composition capture `C:\tmp_shots\m01_ground_no_pool_live.png` confirms pool duplication is reduced, but the white clean-review ambient still overexposes live art; this variant is therefore staging-only and not integrated. It remains useful for isolating pavement ownership in the next lighting pass.


## 2026-10-05T21:51:19 — production-grade clean mode

Changed `GALLERY_CLEAN=1` to preserve the level's production ambient by default; `GALLERY_CLEAN_NEUTRAL=1` is now required for raw white texture inspection. Generated `C:\tmp_shots\m01_ground_no_pool_production_grade.png`; the scene keeps readable contrast without the earlier white wash, while preserving the live pool and lighting. The new no-pool layer remains a staging aid and is not integrated.


## 2026-10-05T21:52:20 — low-alpha no-pool composition

Generated `C:\tmp_shots\m01_ground_no_pool_production_alpha12.png` at alpha 0.12 with the production ambient preserved. The pavement overlay is subtle and the live pool remains the sole pool landmark, but the preview still needs a deliberate final lighting/occlusion approval before runtime integration. No gameplay assets were changed.


## 2026-10-05T21:52:48 — no-pool asset integrity

Verified `ground_no_pool_review.png` as 1920x1080 RGBA with a full non-empty alpha bounding box. Visual quality audit remains clean (`sprites=217`, `decor_entries=300`, no missing imports/alpha/oversized files). This staging layer is valid for review but remains excluded from runtime integration.


## 2026-10-05T21:55:06 — variant contact sheet

Created `C:\tmp_shots\m01_prerender_variants_contact.png` comparing clean alpha32, no-pool alpha32, and no-pool alpha12. The alpha12 no-pool variant has the best gameplay readability and avoids a duplicate pool landmark, but its magenta production light still needs an explicit lighting ownership decision. No variant is promoted to runtime.


## 2026-10-05T21:56:37 — neutral colour staging variant

Generated `ground_no_pool_neutral_review.png` and tested it through `GALLERY_PRERENDER_GROUND_NEUTRAL=1` at alpha 0.16 (`C:\tmp_shots\m01_ground_neutral_alpha16.png`). It suppresses some baked magenta saturation without changing runtime art, but the improvement is subtle at gameplay alpha. Keep it as an optional staging variant; no integration decision is made.


## 2026-10-05T22:00:12 — layer audit coverage

Extended `tools/art/audit_motel_layers.py` to validate all three Sunset Palms staging variants alongside the four runtime-contract layers. Current result: `PASS (4 runtime-contract + 3 staging RGBA layers, 1920x1080)`.


## 2026-10-05T22:02:42 — neutral render from Blender lights

Updated `tools/art/render_motel_layers.py` so `ground_no_pool_neutral_review.png` is rendered with Blender LIGHT objects disabled, rather than post-process colour correction. Blender export, the expanded layer audit, Python compile, and Godot reimport all pass. The neutral pass is still staging-only; it did not remove the level's magenta live lighting and is not integrated.
