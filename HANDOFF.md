# Claude handoff — HOTSHOT California

Updated: 2026-10-05, Europe/Lisbon. Manual handoff requested by the user before session usage is exhausted.

## Session checkpoint (authoritative)

No session-usage percentage is exposed to the agent, so this handoff is created on the user's explicit request rather than inferred from account/model rate limits. Work is paused at the M01 Sunset Palms visual-validation gate; no new art has been integrated into gameplay and no EXE has been generated. Resume from the M01 layer/projection review below.

## Working copy

Continue in this exact checkout:

`C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex`

Branch: `codex/continue-polish`.

The worktree is intentionally very dirty and contains valuable Codex and Claude work. Do **not** run `git reset`, `git clean`, `git checkout --`, or discard unrelated files. Inspect `git status` before making changes.

Important tools:

- Godot console: `C:\Users\gil_n\OneDrive\Ambiente de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Blender: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`
- PixelLab key, never print or commit: `C:\Users\gil_n\.pixellab_key`
- Review/staging: `C:\tmp_shots`

Read `HANDOFF_CLAUDE.md` as the fuller historical record. This file adds the most recent authoritative state.

## Non-negotiable user requirements

- Continue autonomously, but work on **one level at a time**.
- Current level: **M01 Sunset Palms**. Preserve its gameplay layout, collisions, objectives, doors/windows, enemies, and navigation.
- Improve the level toward dense 3/4 high-oblique pixel-art quality: material detail, readable silhouettes, wear, props, warm practicals against cool shadows, motion-ready spaces.
- Audit PixelLab assets before runtime integration; generated output is not approval.
- Integrate art only after visual and gameplay validation.
- Keep the trailer paused. Do **not** generate an EXE.

## Current Sunset Palms pre-rendered environment pilot

This is the active workstream. It is deliberately **not integrated into the Godot level yet**.

Source and outputs:

- Builder: `tools/art/build_prerendered_motel.py`
- Reusable geometry kit: `tools/art/prerendered_kit.py`
- Blender scene: `assets/art/prerendered/m01_sunset_palms/sunset_palms_courtyard.blend`
- High-resolution render: `assets/art/prerendered/m01_sunset_palms/courtyard_master.png`
- Fast iteration render: `assets/art/prerendered/m01_sunset_palms/courtyard_quick.png`
- AI-generated quality/composition target: `assets/art/prerendered/m01_sunset_palms/courtyard_art_target.png`

The latest 1920×1080 render was successfully produced on 2026-10-05. It now contains a dense U-shaped two-storey motel: individual doors/windows/curtains/ACs, balcony rails and lamps, weathered roof detail, stair, furniture, plants, bougainvillea, detailed palms, neon SUNSET PALMS/VACANCY sign, wet asphalt/reflections, pool mosaics/caustics/ladder/coping, and the real-time production Eldorado GLB. The Eldorado is correctly scaled, lit and oriented in the parking lot.

Do not claim this has reached the user’s reference quality yet: the render has substantially moved beyond the earlier blockout, but needs a pixel-art finishing pass and layer separation before it can replace live gameplay art.

Render commands, from repository root:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender -b --python tools/art/build_prerendered_motel.py -- --quick
& $blender -b --python tools/art/build_prerendered_motel.py
```

The builder declares its gameplay footprint contract at the top of the file. Do not move those dimensions without updating the M01 level and verifying navigation.

The explicit mapping for the future Godot layer is recorded in
`assets/art/prerendered/m01_sunset_palms/integration_contract.json`; it keeps the
50×15-tile courtyard region and Blender world footprint together while the art
remains preview-only.
That contract now also records the tested master/layer preview transforms and the
known projection result, so future calibration does not rely on memory.

The dedicated low-resolution Blender source was regenerated and visually inspected:
`assets/art/prerendered/m01_sunset_palms/courtyard_pixel_source.png` (480×270).
The aligned preview passes are now exported under
`assets/art/prerendered/m01_sunset_palms/layers/`: `ground.png`,
`architecture.png`, `props_vegetation.png` and `foreground_occlusion.png`.
They share the master camera and are still preview-only; no Godot scene references
them yet.
`tools/art/audit_motel_layers.py` now checks that all four passes are non-empty RGBA
images with matching dimensions; the regenerated set passes at `1920×1080`.
The current live M01 gameplay gallery was also captured at
`C:\tmp_shots\m01_gallery_current.png`; it confirms the existing gameplay camera,
pool footprint and interactable dressing remain intact while the pre-rendered layer
is still disabled.
The evidence and integration decision are summarized in
`docs/m01_prerender_review.md`.

For pixel-art evaluation only, `courtyard_pixel_preview.png` is a nearest-neighbour
1920×1080 upscale of `courtyard_pixel_source.png`. It is intentionally not wired
into Godot: the reduced source preserves composition but still needs a deliberate
palette/edge pass before it can satisfy the supplied reference quality.
`courtyard_pixel_art_candidate.png` is a second evaluation variant using a fixed
96-colour, no-dither palette reduction plus nearest upscale; it reads closer to
the target pixel language but remains review-only until the in-game camera and
layer projection are approved.
The generator now compresses only the top highlight range before quantization so
the neon stays luminous without erasing nearby trim and foliage detail.
Regenerate it reproducibly with `python tools/art/make_pixel_candidate.py`.
Audit it with `python tools/art/audit_pixel_candidate.py` before visual review.
Build a side-by-side sheet with `python tools/art/make_pixel_comparison.py`.

The `scout`/`civilian` look tone was refined from `1.12` to `1.24` in
`scripts/player/cast_model.gd`; `C:\tmp_shots\cast_review_m01\scout_tone124.png`
confirms improved separation against the wet asphalt without changing the mesh.
The dark trio (`sniper`, `stagehand`, `riot`) was similarly refined from `0.74` to
`0.60`; `C:\tmp_shots\cast_review_m01\sniper_tone060.png` confirms the sniper is
more readable while retaining the cool shadow treatment.

Post-calibration validation is green: `visual_quality_audit.py` reports 217 sprites,
91 pixel shots and no missing imports; `audio_reference_audit.py` reports 38/38 audio
references; `polish_layouts.py --check` reports all four levels reachable; and the
Godot smoke test passes the full movement/combat/AI/checkpoint/boss sequence.
The latest repeat also passes `python tools/art/audit_motel_layers.py` with four
non-empty RGBA layers at `1920×1080`; `git diff --check` remains clean.

An opt-in gallery comparison is available with `GALLERY_PRERENDER=1` and writes to
`C:\tmp_shots\m01_prerender_preview_alpha.png`. The first calibrated transform
(`plate.position = Vector2(464, 296)`, scale `0.333333`, alpha `0.62`) is retained
because a trial translation moved the pool out of alignment. The pool/parking read
well, but the motel wing projection does not yet match the live wall extents; this is
an evidence-based integration blocker. Keep the plate disabled and solve the crop or
camera projection before enabling it in gameplay.

For a layer-only test, set `GALLERY_PRERENDER_LAYERS=1` and
`GALLERY_PRERENDER_SCALE=1.0`; the resulting capture is
`C:\tmp_shots\m01_prerender_layers_scale1.png`. This shows the ground/pool and
prop pass can sit over the live architecture with useful alignment, but it remains a
review plate, not a shipped integration.
To compare the palette candidate in the real M01 camera, add
`GALLERY_PRERENDER_PIXEL=1`; this is also opt-in and preview-only.
Captura interactiva concluída com renderer Windows em
`C:\tmp_shots\m01_pixel_candidate_gallery.png`. O pool e o estacionamento alinham
de forma útil, mas a ala do motel invade a arquitetura live; a projeção continua
reprovada e deve ser corrigida antes de integração.
Também foi concluída a captura ground-only em
`C:\tmp_shots\m01_ground_only_interactive.png`, usando
`GALLERY_PRERENDER_GROUND_ONLY=1`, escala `0.333333` e alpha `0.42`. Esta é a
melhor variante híbrida até agora: solo e piscina alinham-se sem duplicar props,
mas só passa o sub-gate da base. Mantém a arte fora do gameplay até validar
movimento, portas, objetivos, contraste e oclusão numa captura real.
Foi testado também `C:\tmp_shots\m01_ground_only_alpha028.png` com alpha `0.28`;
mantém o alinhamento e reduz a coloração sobre a arte live, mas permanece apenas
um candidato de revisão.
O teste `C:\tmp_shots\m01_ground_only_player028.png`, centrado no jogador, não
enquadrou o jogador de forma útil; portanto ainda não prova contraste do elenco.
O próximo passo é ajustar o probe/câmara ou capturar depois de o spawn estabilizar.
Para validar contraste sem depender da `ViewportTexture` 3D, a galeria aceita
`GALLERY_PLAYER_FALLBACK=1`, que desenha uma frame 2D do Cass apenas na captura.
`C:\tmp_shots\m01_ground_only_2d_fallback_scale1.png` é a evidência actual;
continua preview-only.
Para repetir testes em células específicas sem tocar no nível, `tools/level_gallery.gd`
agora aceita `GALLERY_PLAYER_CELL=x,y` em modo de galeria.
O diagnóstico já confirma a posição forçada e `visible=true`, mas o sprite não é
desenhado; investigar o estado de animação/escala do `CharacterVisual` é o próximo
passo antes de validar contraste.
Uma tentativa de calibração automática por imagem também foi adiada porque o
ambiente não tem OpenCV; não instalar dependências nem substituir a revisão visual
por uma máscara de cor simplificada.

### Latest Blender pass (current authoritative state)

The builder was edited in `tools/art/build_prerendered_motel.py` to add recessed warm
under-gallery lights and rooftop service clutter (vents, conduits and maintenance
crates). A fast render completed successfully after this change:

`assets/art/prerendered/m01_sunset_palms/courtyard_quick.png`

The full master render was produced immediately before this pass and remains the
high-resolution reference:

`assets/art/prerendered/m01_sunset_palms/courtyard_master.png`

The regenerated `courtyard_quick.png` was visually checked after the latest builder
pass; recessed gallery lights and rooftop service clutter are present and legible.
The full master and all four transparent layers were regenerated again from the
current builder on 2026-10-05; `audit_motel_layers.py` passes at 1920×1080.

The `.blend` scene is reproducible from the builder; it has not been integrated into
the Godot level. The full-resolution master was regenerated successfully after the
detail pass. A headless smoke run now passes the gameplay assertions without the
previous `texture_2d_get` warning: the roll ghost path reuses the live viewport
texture directly. Then create aligned render layers (ground,
architecture, props/vegetation, foreground occlusion and light FX). Do not replace
the live M01 art until a real in-game capture confirms navigation, collision,
objective readability and player contrast.

The current workspace is intentionally dirty. Do not discard existing changes. The
user has transferred the complete project ownership to Codex for this pass; Claude is
only the later recipient of this handoff.

## Recommended next sequence

1. Run the full Blender render and inspect `courtyard_master.png` against `courtyard_art_target.png` and the supplied reference images in `C:\Users\gil_n\OneDrive\Ambiente de Trabalho\IMAGENS JOGO`.
2. Produce a pixel-art-ready version of the approved geometry: render separate ground, architecture, props/vegetation and foreground-occlusion layers, then apply a deliberate low-resolution pixel-art pass. Do not use a blind smoothing filter.
3. Map the artwork precisely to `levels/m01_sunset_palms.json`, retaining the existing collision/objective/enemy layers.
4. Capture real M01 gameplay with the new visual layer, assess readability/occlusion/player contrast, then run the smoke test and audits before considering it integrated.
5. Only after M01 is visually and functionally approved, move to M02.

## Existing wider project work

Claude’s current 3D character pipeline and game changes are already in the dirty tree. The current primary runtime implementation is `scripts/player/cast_model.gd`; 24 runtime GLBs are present in `assets/art/cast3d_rt/`. Keep the old character handoff history intact and do not overwrite it. Read `HANDOFF_CLAUDE.md` for detailed cast, PixelLab, cutscene, audio and validation notes.

## Validation commands

```powershell
Set-Location 'C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex'
$godot = 'C:\Users\gil_n\OneDrive\Ambiente de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
python tools/visual_quality_audit.py
python tools/audio_reference_audit.py
python tools/polish_layouts.py --check
git diff --check
& $godot --headless --path . res://tools/smoke_test.tscn
```

The latest full headless smoke sequence completed with `=== SMOKE TEST DONE: 0 failures ===` across M01 and M02 after the opt-in gallery change. Godot still reports 8 leaked ObjectDB instances and 3 resources in use at process exit; these are teardown diagnostics only and do not fail the assertions. Rerun after any integration change. Do not generate an EXE.

Latest safeguards: `tools/art/render_motel_layers.py` now refuses to render unless
the loaded Blender scene uses `Courtyard master camera` and contains mesh objects;
this prevents an empty default Blender scene from overwriting layers. The gallery
also supports `GALLERY_PRERENDER_OFFSET=x,y` for preview-only crop tests and exits
cleanly when a headless/dummy renderer has no viewport image. Visual captures must
use the real Godot renderer/editor; these changes do not alter normal gameplay.

Latest real-renderer evidence is in `C:\tmp_shots\m01_real_renderer_offset0.png`,
`C:\tmp_shots\m01_real_renderer_offset_neg80.png` and
`C:\tmp_shots\m01_real_renderer_offset_pos80.png`. The centered plate `(464,296)`
remains the best preview crop; both ±80 tests were rejected for poorer alignment.
The NPC lineup preview now also exits cleanly under a headless/dummy renderer;
use the Windows renderer for visual lineup captures.
The six cutscene contact sheets in `C:\tmp_shots\cutscene_audit\` were inspected;
all 91 runtime-referenced shots remain readable and perspective-consistent.
`tools/cutscene_contact_sheet.py` now fails explicitly if any runtime-referenced
shot is missing before creating a contact sheet.

## Latest verified continuation — Eldorado 3D (2026-10-05)

- `scripts/levels/car_model.gd` tuned after real GUI captures: reduced 3D car lighting energy from `0.5` to `0.38`, moved the driver seat slightly inward/up to `Vector3(0.34, 0.025, 0.0)`, and shortened the outside/behind-door path to `OUT_STEP=0.92`, `BACK_STEP=0.48`. This keeps Cass inside the cabin during the drive and clears the open door without crossing it.
- Visual evidence inspected: `C:/tmp_shots/car_arrival_tuned/contact.jpg` (20 arrival frames) and `C:/tmp_shots/car_depart_latest/contact.jpg` (14 departure frames), captured with the GUI Godot renderer. Arrival shows a continuous curved entry/drift, braking, open door and seated driver; departure shows the door handoff and peel-out. These are review captures only; gameplay logic remains unchanged.
- Validation after the tune: `visual_quality_audit.py` PASS (217 sprites, 300 decor, 91 pixel shots, no missing imports/alpha/shots), `audio_reference_audit.py` PASS (38 refs), `polish_layouts.py --check` PASS for all four levels, `git diff --check` PASS, and full `tools/smoke_test.tscn` PASS with `0 failures` (M01 and M02).
- Next concrete step: continue one-level-at-a-time on M01 Sunset Palms, inspect the real rendered pre-rendered layers against the gameplay grid, and only integrate a layer after visual and gameplay validation. Keep trailer paused and do not generate EXE.
- 2026-10-05 layer review: rebuilt all four Blender layers and re-ran both audits (PASS). Real Godot renderer preview `C:/tmp_shots/m01_ground_latest.png` with `GALLERY_MISSION=m01_checkout`, ground-only, alpha 0.28 confirms pool/wet pavement scale and center align with the gameplay camera. The plate still overlays live architecture/props at review opacity, so it remains staging-only; no runtime level art was replaced.
- Added `GALLERY_PRERENDER_PIXEL_HQ=1` to `tools/level_gallery.gd` for a controlled, review-only composition test. It does not affect normal gameplay.
- Fixed a real teardown diagnostic in `scripts/weapons/bullet_system.gd`: hit-confirm now checks `is_instance_valid(b.shooter)` before the typed `Player` test, so bullets that outlive a dead/boss shooter no longer evaluate a freed instance. Full smoke test after the fix: `=== SMOKE TEST DONE: 0 failures ===` with no previous freed-instance error in the output.
- Runtime character review: `C:/tmp_shots/cast_guard_lineup.png` and zoomed `cast_guard_lineup_zoom_crop.png` were captured with the real renderer. Guard alive, armed, downed and corpse poses keep one oblique direction, readable silhouettes and consistent scale; no overhead/frontal replacement art was promoted. The lineup tool remains review-only.
- Boss runtime lineup review found the pale Meshy material was clipping under the shared character light. `CastModel` now stores the look id and uses a reduced stage energy for `boss` (0.48) and `fireman` (0.72), plus tone exponents for boss/fireman/burnt. New capture `C:/tmp_shots/cast_boss_lineup_tuned2_crop.png` shows the jacket/skin/weapon planes separated while preserving the same oblique pose and scale; no asset replacement was needed.
- Fireman follow-up capture `C:/tmp_shots/cast_fireman_lineup_crop.png` was visually inspected after the stage-energy adjustment. White suit remains bright by design but shadow planes, face, arms and weapon silhouette are readable; no further tone change was made.
- Full smoke validation after boss/fireman lighting changes: `=== SMOKE TEST DONE: 0 failures ===` across M01 and M02. The remaining ObjectDB/resource messages are teardown diagnostics only; no gameplay assertion failed.
- Creature review: `C:/tmp_shots/cast_zombie_lineup_crop.png` inspected in the real renderer. Zombie's hunched silhouette, hands and downed/corpse states remain readable against the night floor; magenta rim is intentional and does not clip the silhouette. No replacement art was integrated.
- Creature review: `C:/tmp_shots/cast_ghoul_lineup_crop.png` inspected. The ghoul's elongated arms, hunched posture, weapon hand and fallen/corpse silhouettes are readable; perspective remains oblique and consistent. No art replacement integrated.
- Creature review: `C:/tmp_shots/cast_cultist_lineup_crop.png` inspected. Hooded silhouette, robe hem, extended hands and weapon pose remain clear in the dark; downed/corpse reads cleanly. No replacement art integrated.
- Creature review complete: `C:/tmp_shots/cast_demon_lineup_crop.png` inspected. Demon horns, wings, tail, hands and downed/corpse silhouettes read clearly in the red rim light; no limbs or perspective errors found. No replacement art integrated.
- Cutscene audit rerun: `tools/cutscene_contact_sheet.py` regenerated six contact sheets in `C:/tmp_shots/cutscene_audit/`; page 3 was visually inspected again and subjects/actions remain clear and consistent. `audio_reference_audit.py` remains 38/38 with no missing refs.
- Kennel kit runtime review: `C:/tmp_shots/kennel_latest_crop.png` (crop of `kennel_latest.png`) was captured with the GUI renderer and inspected. Cage, bed and two bowls read cleanly at runtime scale with coherent oblique edges; no collision or gameplay changes were made.
- Fuse state review rerun: `C:/tmp_shots/fuse_latest.png` was captured with the real renderer. Both POWER ON and DESTROYED states have distinct, readable silhouettes and labels; the active Fuse/BreakableProp integration remains visually approved.

- M03/M04 real-renderer gallery load validation: captures C:/tmp_shots/m03_gallery.png and C:/tmp_shots/m04_gallery.png loaded successfully after prewarming 16/14 looks; visually inspected, no obvious missing level content. This is a review capture, not gameplay integration.


- Final smoke validation rerun on 2026-10-05: 
es://tools/smoke_test.tscn completed with === SMOKE TEST DONE: 0 failures ===; M01 and M02 gameplay paths, combat, AI, doors, props, cutscenes, car exits and save/load checks passed.


- M01 pixel HQ refinement: highlight compression changed 0.45 -> 0.70 in 	ools/art/make_pixel_candidate_hq.py; regenerated candidate preserves neon/window highlights and dark foliage separation. Audit passes (1920x1080, 92 colours); preview-only, not runtime-integrated.


- Added review-only GALLERY_PRERENDER_ISOLATE=1 in 	ools/level_gallery.gd. It hides live Walls/Decor/Props/Floor/Visual3DDressing roots while preserving gameplay nodes and collisions, allowing a reproducible Blender plate occlusion/alignment capture before integration. Normal runtime is unchanged; editor compile passes.


- M01 isolation capture completed on real renderer: C:/tmp_shots/m01_ground_isolated.png. Ground/pool alignment is readable with live gameplay markers retained; preview-only, no runtime integration yet.


- Full M01 HQ isolation capture: C:/tmp_shots/m01_pixel_hq_isolated.png. Pool, parking, sign and palm crop align in staging; runtime actors remain visible, but full plate still changes readability, so it is not integrated.


- Runtime regression check after adding gallery isolation: normal M01 capture C:/tmp_shots/m01_normal_after_isolation.png loaded on the real renderer with the original live pool, dressing, FX and actors intact. Isolation is opt-in and does not affect normal composition.


- UI/cutscene regression audit rerun after M01 visual changes: python tools/cutscene_contact_sheet.py regenerated 6 contact sheets under C:/tmp_shots/cutscene_audit/; page 1 visually inspected and framing/subjects remain readable. visual_quality_audit.py: 217 sprites, 300 decor entries, 91/91 pixel shots, no missing imports/alpha/oversized assets. audio_reference_audit.py: 38/38 audio references present.


- M01 hybrid ground pass: generated layers/ground_no_emissive_review.png with baked highlights compressed and captured C:/tmp_shots/m01_ground_no_emissive.png; geometry remains aligned and gameplay markers readable. Review-only, not runtime-integrated.


- Layout reachability rechecked after M01 review tooling: python tools/polish_layouts.py --check passes for M01 (19 regions), M02 (6), M03 (18), M04 (9); all entities reachable and no single-exit rooms.


- Gameplay regression after M01 ground review tooling: 
es://tools/smoke_test.tscn completed with === SMOKE TEST DONE: 0 failures ===; M01/M02 combat, AI, doors, props, cutscenes, escapes and save/load remain green.


- Ground no-emissive alpha comparison: C:/tmp_shots/m01_ground_no_emissive_alpha12.png is too subdued; review range should remain roughly alpha 0.22-0.30. No runtime integration.


- Selected M01 ground review reference: C:/tmp_shots/m01_ground_no_emissive_alpha22.png (no-emissive variant, alpha 0.22). Best balance found between pool detail and gameplay contrast; still preview-only.


- Original M01 Blender layer integrity rechecked after creating the no-emissive review variant: python tools/art/audit_motel_layers.py passes (4 RGBA layers, common 1920x1080). The generated review variant remains separate and does not replace the source export.


- Final asset/audio audit after M01 review variant: 217 sprites, 300 decor entries, 91/91 pixel shots, 0 missing imports/alpha/oversized/missing shots; audio references 38/38.


- Revalidated M01 art gates: pixel candidate audit PASS (1920x1080, 92 RGB colours, non-empty alpha) and original layer audit PASS (4 RGBA layers, common 1920x1080).


- Reproduced the M01 HQ pipeline from sunset_palms_courtyard.blend with Blender 5.2.2: source HQ rendered successfully, pixel candidate regenerated, candidate audit PASS (1920x1080, 92 colours), and layer audit remains PASS.


- Godot editor reimport/compile after Blender HQ regeneration completed successfully; both HQ PNGs reimported and editor quit cleanly. git diff --check passes.


- Added assets/art/prerendered/m01_sunset_palms/ground_review_comparison.png, side-by-side original/no-emissive ground. Geometry is unchanged; only baked highlight intensity differs.


- Re-inspected the existing real-renderer galleries C:/tmp_shots/m03_gallery.png and C:/tmp_shots/m04_gallery.png: M03 studio/parking routes and M04 mansion/ritual layout remain visually readable with actors, objectives and props present; no new missing-content issue observed.


- Reproduction command for the selected M01 ground review: set GALLERY_MISSION=m01_checkout, GALLERY_PRERENDER=1, GALLERY_PRERENDER_GROUND_ONLY=1, GALLERY_PRERENDER_GROUND_NO_EMISSIVE=1, GALLERY_PRERENDER_ISOLATE=1, GALLERY_PRERENDER_ALPHA=0.22, GALLERY_PLAYER_CELL=20,20, GALLERY_PLAYER_FALLBACK=1, GALLERY_SHOW_PLAYER=1, then run 
es://tools/level_gallery.tscn with the real renderer and save to C:/tmp_shots/m01_ground_no_emissive_alpha22.png.



## Validação autónoma 2026-10-05
- Smoke test Godot executado após o estado atual: `=== SMOKE TEST DONE: 0 failures ===`.
- M01: combate, portas, props, boss, cutscene, telefone, carro, resultados e save/load passaram.
- M02: cães, stealth, luzes, fusível, gore, Buck, carro, resultados passaram.
- Os avisos finais são apenas leaks de ObjectDB/resources na saída do harness; não houve falhas de gameplay.
- Arte pré-renderizada M01 continua em revisão: não integrar full plate nem alterar runtime sem gate visual/aprovação.


## Verificação de integridade 2026-10-05
- Referências de áudio: 38, ausentes: 0.
- Layouts: M01 19, M02 6, M03 18, M04 9; regiões alcançáveis e sem salas de saída única.
- `git diff --check`: PASS.
- Godot editor headless scan/import/quit: PASS.


## Revisão de cutscenes 2026-10-05
- `python tools/cutscene_contact_sheet.py` regenerou as 6 folhas em `C:/tmp_shots/cutscene_audit/`.
- A página 06 foi reinspecionada: sujeitos, ação e composição permanecem legíveis; `vance_boys` mantém a diferença estilística já conhecida, sem bloquear a leitura narrativa.
- Nenhuma pintura foi promovida ou removida nesta revisão.


## Smoke regressão 2026-10-05
- Execução completa após a revisão de cutscenes: `=== SMOKE TEST DONE: 0 failures ===`.
- M01 e M02 passaram novamente incluindo combate, IA, portas, bosses, cães, stealth, luzes, cutscenes, escapes, carros e save/load.
- Warnings de teardown (ObjectDB/resources) permanecem apenas no encerramento do harness.


## Verificação Blender 2026-10-05
- `sunset_palms_courtyard.blend` abriu com Blender 5.2.2 sem erros: 142 objetos, 56 materiais e 1 câmara.
- A fonte permanece reproduzível para novas iterações; não houve alteração do runtime Godot nem integração da placa pré-renderizada.


## Auditoria de camadas 2026-10-05
- Após reabrir a cena Blender, `audit_motel_layers.py` e `audit_pixel_candidate.py` continuam PASS (4 camadas RGBA 1920x1080; candidato HQ 92 cores RGB, alfa válido).


## Regeneração determinística 2026-10-05
- `make_ground_review_variant.py` regenerou `layers/ground_no_emissive_review.png` (1920x1080 RGBA) a partir da camada fonte.
- Auditorias de camadas e candidato HQ continuam PASS; o ficheiro permanece preview-only e não modifica o runtime.


## Rebuild HQ Blender 2026-10-05
- Rebuilt `courtyard_pixel_source_hq.png` and saved `sunset_palms_courtyard.blend` with Blender 5.2.2.
- Exported all four aligned layers from the saved scene: ground, architecture, props_vegetation and foreground_occlusion.
- Recreated `ground_no_emissive_review.png` from the fresh ground layer.
- Layer and pixel candidate audits pass; all outputs remain preview-only.


## Reimportação e smoke após rebuild 2026-10-05
- Godot reimportou as 7 imagens HQ/layers sem erro e saiu limpo.
- Smoke test completo terminou em `=== SMOKE TEST DONE: 0 failures ===`; M01/M02 permanecem verdes.


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

## Latest authoritative checkpoint — 2026-10-06, Europe/Lisbon

The user explicitly requested this handoff for Claude. Continue in the same checkout and preserve all existing uncommitted work.

### Current state

- Active level remains **M01 Sunset Palms**; work one level at a time.
- Exterior Blender master is approved as the quality reference for the pool courtyard, but the interiors are still **staging-only** because their detail density has not yet matched the pool courtyard.
- Interior staging scene: `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\assets\art\prerendered\m01_sunset_palms\staging\m01_interiors_transitions_staging.blend`.
- Latest Blender inspection: **385 objects / 12 materials**.
- Standard staging renders: `m01_interiors_transitions_staging.png`, `m01_reception_detail_staging.png`, `m01_service_transition_detail_staging.png` in the staging directory.
- Optional 4K review renders are in `staging\4k\` and are validated at 3840x2160.
- Staging now includes material micro-bump, floor inlays, wall rails/pilasters, authored doors/signage, AC units and conduits, bathroom nooks, reception trolley/extinguisher, laundry shelves/linen/drains, safety markings, framed art, towels, wear decals and practical lighting.
- Runtime integration remains limited to the previously approved low-alpha M01 ground plate in `scripts\levels\level.gd`; do not promote interior layers without visual approval.
- Pool water animation remains in Godot via `PoolFX`; pool floats use `AnimatedProp` for slow bob/drift.
- Trailer remains paused. No EXE has been generated.

### Required reading / source files

- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\assets\art\prerendered\m01_sunset_palms\ART_DIRECTION.md`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\assets\art\prerendered\m01_sunset_palms\STAGING_STATUS.md`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\docs\m01_prerender_review.md`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\tools\art\build_m01_interiors.py`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\tools\art\audit_m01_staging.py`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\tools\art\audit_m01_runtime_isolation.py`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\tools\art\audit_m01_interior_4k.py`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\tools\art\audit_motel_layers.py`
- `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex\tools\smoke_test.tscn`

### Validation commands

```powershell
Set-Location 'C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex'
python tools/art/audit_m01_staging.py
python tools/art/audit_m01_runtime_isolation.py
python tools/art/audit_m01_interior_4k.py
python tools/art/audit_motel_layers.py
python tools/visual_quality_audit.py
python tools/audio_reference_audit.py
python tools/polish_layouts.py --check
python tools/art/audit_pixel_candidate.py
& 'C:\Users\gil_n\OneDrive\Ambiente de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . res://tools/smoke_test.tscn
```

Expected current results: staging PASS; runtime isolation PASS; interior 4K PASS for three 3840x2160 renders; prerender contract PASS; visual audit 217 sprites / 300 decor entries / 91 pixel shots with zero missing; audio 38/38; all M01–M04 layout entities reachable; PixelLab candidate PASS; full Godot smoke `0 failures`.

### Blocker and next concrete step

The only intentional blocker is the visual promotion gate: the interiors still look less authored/dense than the pool courtyard at 100%/4K. Keep live Godot art authoritative. Continue the next Blender pass in M01 only, prioritising authored micro-props, material variation, readable practical-light pools and 3/4 camera composition. After the pass, regenerate standard and optional 4K renders, run every audit above, inspect the images at 100%, and promote at most one zone only after visual and gameplay approval. Do not move to M02 until M01 is accepted.

### Working rules

- Do not use `git reset`, `git clean`, checkout/discard, or overwrite unrelated dirty work.
- Do not print or commit the PixelLab key at `C:\Users\gil_n\.pixellab_key`.
- Do not generate an EXE or resume trailer capture.
- Do not create another handoff based on account/model rate limits; this file was created now because the user explicitly requested it. Session percentage is not exposed.

## 2026-10-06 — continuação do Claude (interiores M01)

Feito (tudo staging-only; nada promovido para o runtime):
- `tools/art/build_m01_interiors.py` reconstruído com o kit do pátio (`prerendered_kit.MB`, palmeiras e plantas reais) e materiais com padrão (papel de parede às riscas, alcatifa, xadrez no lobby e na lavandaria, colchas florais, madeira com veio).
- Props de autor: cama de casal com colcha, almofadas e cabeceira com botões; mesinhas de cabeceira com candeeiro aceso (luz pontual) e telefone; cómoda com TV CRT a brilhar; poltrona de vinil; mesa com revistas e latas; desarrumação; máquinas de lavar; carrinho de roupa; prateleiras com toalhas e frascos; balde e placa de chão molhado; sofá de vinil no lobby; carrinho de bagagem de latão; máquina de venda a brilhar; painel de chaves com porta-chaves; campainha, registo e livro no balcão; plantas em vasos.
- Os blocos genéricos antigos foram removidos. Há uma cópia do construtor do ChatGPT em `C:\tmp_shots\build_m01_interiors_gpt_backup.py`.
- Previews de píxel, contact sheet e as três vistas em 4K regeneradas. Auditorias PASS: staging, runtime isolation, layers, interior 4K e visual. `git diff --check` limpo.

Gate visual (comparação `C:\tmp_shots\pool_vs_reception.png`): **ainda reprovado**. A densidade de props melhorou muito, mas os interiores continuam abaixo do pátio da piscina:
1. **Iluminação**: os interiores estão uniformemente claros. A piscina é noite escura com poças de luz quente e fria. Fazer o seguinte: baixar a área de luz global (`energy 1800`) e as áreas azuis; deixar a luz vir dos candeeiros, das janelas, do néon e da TV; acrescentar luzes de janela com cortinas.
2. **Néon e reflexos**: dar aos interiores néon próprio (letreiro "OFFICE", máquina de venda) e chão encerado com reflexo (usar `wet_ground` / `mirror` do construtor do pátio no xadrez do lobby).
3. **Densidade**: acrescentar quadros, sinais e autocolantes nas paredes, cortinas a sério, tapetes com franja, caixotes do lixo, um bebedouro, uma máquina de gelo e plantas penduradas, ao nível do pátio.
4. **Fundo**: o mundo é cinzento. Usar quase preto, como no pátio.
Depois de cada passo: correr `blender -b --python tools/art/build_m01_interiors.py`, `pixelize_m01_staging.py`, `contact_m01_pixel_previews.py` e as auditorias, e comparar lado a lado com `courtyard_master.png`. Só depois de passar no gate promover uma única zona.

### 2026-10-06 (2) — passe nocturno + identidade por zona (Claude)
- Utilizador: "a qualidade da piscina é só uma ajuda, cada área deve ter a sua identidade". A piscina define o nível de acabamento, não o estilo.
  - **Quarto:** quente e acolhedor, com candeeiros âmbar, um candeeiro de pé e o néon rosa pela janela.
  - **Lavandaria:** fria e de serviço, com tubos fluorescentes verde-brancos, parede em azulejo, vapor, canos com válvulas, estendal com roupa, detergentes, cestos e o néon LAUNDRY ciano.
  - **Receção:** lobby retro, com néon OFFICE rosa, madeira quente, janela azul, expositor de folhetos e cinzeiro de pé.
- Iluminação passada para noite: luz global 1800→260, áreas azuis 260→70, práticas mais fortes, fundo e mundo quase pretos, view transform AgX Punchy. Chão do lobby e da lavandaria brilhante para refletir as luzes.
- Paredes de todas as salas: quadros, relógio, caixote do lixo, planta de canto.
- Orçamento de sombras do EEVEE: as luzes pontuais e spot com menos de 100 de energia não projetam sombra.
- Auditorias staging e isolation: PASS.
- **Gate ainda reprovado.** Próximos passos:
  - densidade nas paredes laterais e no corredor (que continua vazio e plano);
  - texturas de desgaste no chão;
  - ajustar as cores do néon e confirmar a nova vista de conjunto.
  - Nada foi promovido para o runtime.

### 2026-10-06 (3) — corredor e paredes laterais (Claude)
- **Corredor:** passadeira; máquina de gelo e máquina de venda; caixa de extintor; setas com o número dos quartos; poças com reflexo; caixote do lixo; caixa de toalhas; 4 pontos de luz quente ao longo do corredor.
- **Paredes laterais das salas:** quadros, tomadas e termóstato. No chão, riscos subtis em vez das manchas pretas, que pareciam buracos.
- Renders e previews regenerados. Auditorias staging e isolation: PASS. `git diff --check` limpo.
- **Gate ainda reprovado.** Próximo passo:
  - o corredor continua quase vazio visto de cima: pôr props no meio-lado e ver se a máquina de venda não tapa tudo;
  - as janelas exteriores dos quartos precisam de leitura mais clara;
  - comparar outra vez lado a lado com o `courtyard_master.png`.

### 2026-10-06 (4) — props Meshy importados no Blender (Claude)
- O utilizador autorizou APIs. Gerei 18 props de interior no Meshy (`int_*` em `tools/art/characters3d.json`; modelos em `assets/art/Artwork/3d/int_*/model.glb`, cerca de 450 créditos, sobram cerca de 790).
- `prop(pid, x, y, h, rot, fallback, width)` em `build_m01_interiors.py` importa o GLB para a cena Blender: junta as malhas, escala à altura ou largura, pousa no chão e roda. Se o ficheiro faltar, usa o prop procedural.
- **Consistência visual** (o utilizador pediu que nada pareça "de Meshy" ao lado de "de Blender"): `unify_material()` aplica a cada material importado o mesmo grão e bump dos procedurais, acabamento mate (roughness .65) e saturação .82. Tudo é renderizado com as mesmas luzes, câmara e grade AgX, e a passagem de píxel unifica o resto.
- Já em uso: cama, mesinhas com candeeiro, cómoda com TV, poltrona, máquinas de lavar, carrinho de roupa, prateleira de lençóis, sofá do lobby, balcão da receção, carrinho de bagagem, máquinas de venda (lobby e corredor), bebedouro, máquina de gelo, malas.
  - Ainda por usar: `int_key_rack`, `int_coffee_table`, `int_room_ac`, `int_palm_pot` (nesta zona as palmeiras procedurais do kit leem bem).
- **Correções:**
  - restos procedurais sobrepostos (cómoda/minibar);
  - os adereços e o corrimão do corredor invadiam o quarto de cima e passaram a ficar só no troço visível (y −7,5..1,4);
  - câmara da lavandaria passada para frontal 3/4 (a parede tapava metade da imagem);
  - retiradas peças planas antigas (passadeira salmão, riscas, etiquetas a flutuar, vapor em losangos).
- Auditorias staging e isolation: PASS. `git diff --check`: limpo.
- **Gate ainda reprovado.** Falta, por ordem:
  1. lavandaria mais densa: cestos com roupa, prateleiras cheias, canos e válvulas visíveis, cartazes, máquinas de secar empilhadas, caixote do lixo, toalhas no chão;
  2. quarto: cortinas a sério e luz de janela visível;
  3. receção: `int_key_rack` na parede e tapete;
  4. 4K e comparação lado a lado com `courtyard_master.png`.

- (4b) Lavandaria, passagem de densidade: segundo carrinho e segunda prateleira (Meshy), cestos com roupa, toalhas no chão, caixote do lixo, cartazes e relógio na parede de azulejo. Auditorias PASS. Próximo: cortinas e luz de janela no quarto, `int_key_rack` e tapete na receção, 4K e comparação com o pátio.

- (4c) Receção: `int_key_rack` Meshy na parede (`wall_prop`) e tapete duplo. Quarto: cortinas plissadas com sanefa e parapeito a enquadrar a janela de néon. 4K regenerado. Auditorias staging/isolation/4K/layers: PASS. Gate: falta a comparação final lado a lado com `courtyard_master.png` e a aprovação do utilizador antes de promover uma zona.

### 2026-10-06 (5) — ESTADO FINAL DESTA SESSÃO DO CLAUDE (ler primeiro)
Feito nesta ronda (staging only, auditorias PASS, `git diff --check` limpo):
- **Mesmo tratamento de render do pátio aplicado às salas**: EEVEE 96 amostras, raytracing, fast GI, sombras, AgX Medium High Contrast com exposição −0,35 e bloom no compositor (bloco `sc.view_settings...` em `build_m01_interiors.py`).
- **Composição revista**, porque o utilizador pediu que "nada pareça colocado ao calhas":
  - Quarto: janela à esquerda sobre a secretária; palmeira no canto (já não tapa a cómoda com TV); malas na parede junto à porta; mesa de apoio sobre o tapete junto à poltrona; tirado o saco solto.
  - Lavandaria: cestos à frente das máquinas; balde, esfregona e placa em cavalete junto à poça das máquinas; prateleira rodada ao fundo da parede esquerda; tirado o segundo carrinho; mesa de dobrar com tampo laminado claro e toalhas; canos metálicos com válvulas.
  - Receção: sofá na parede esquerda virado para a direita; mesa de centro; duas poltronas do outro lado viradas para o sofá; candeeiro de pé; carrinho de bagagem na parede direita.
- **Removidos restos toscos do construtor antigo**: "frascos" planos pendurados; juntas laranja tipo hambúrguer; cilindros-cesto empilhados; banco de madeira; caixote de lençóis; riscos azuis; cartões no estendal; espelho/lavatório ciano; prateleira de caixinhas; caixas da receção (porta-correio, expositor, monitor, barra de néon, placa); juntas de mosaico na alcatifa; chão e passadeira do corredor que apareciam por baixo do quarto.
- **Orientação dos modelos Meshy**: com `rot=0` a frente fica virada para a câmara (−Y). Rodar +π/2 vira a frente para +X; −π/2 vira-a para −X.

**Gate: REPROVADO pelo utilizador. Motivo: NÍVEL DE DETALHE** (não composição, não luz). O pátio tem coisas em cada metro quadrado; as salas têm grandes áreas vazias e superfícies nuas. Plano para a próxima passagem, por ordem:
1. **Diminuir o vazio**: as salas são grandes (9×4,2 m e 10×5,5 m). Encher cada zona do chão com props com função; nenhuma área livre maior do que cerca de 1 m², exceto as faixas de passagem do jogador.
2. **Quarto**: suporte de malas com mala aberta e roupa; tabuleiro de room service na cama; cinzeiro, copos, balde de gelo e comando na cómoda; cesto de papéis; tábua de engomar encostada; varão com cabides; telefone de parede; aquecedor de rodapé; candeeiro de teto ou ventoinha; manchas de humidade no teto; tomadas e interruptores; sapatos; revistas no chão; cortinas também nas laterais.
3. **Receção**: balcão com bandejas, carimbos, livro de reservas aberto, caneca, sino e cartões; parede de fundo com relógios de fusos horários, licença emoldurada e porta "STAFF ONLY"; expositor de folhetos real; tapete de entrada; bengaleiro; vasos com flor; máquina de tabaco; telefone público.
4. **Lavandaria**: máquinas de secar empilhadas, cestos com roupa a transbordar, garrafas de detergente reais (modelos, não caixas), quadro de avisos com papéis, cabides com fardas, carrinho de limpeza, extintor, grelha de ralo, caixa elétrica com cabos.
5. Muitos destes objetos podem vir do Meshy (há cerca de 790 créditos), sempre importados com `prop()` / `wall_prop()` e uniformizados com `unify_material()`.
6. Depois de cada passagem: render, os 3 close-ups e a vista de conjunto. Rever tudo a 100% (objetos sobrepostos, flutuantes, a atravessar paredes, mal orientados ou sem razão de estar ali), comparar com `courtyard_master.png` e correr as auditorias. Só promover uma zona com aprovação explícita do utilizador.
