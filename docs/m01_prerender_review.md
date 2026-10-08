# M01 Sunset Palms — revisão pré-integração

## Evidência revista

- `assets/art/prerendered/m01_sunset_palms/courtyard_master.png`
- `assets/art/prerendered/m01_sunset_palms/courtyard_pixel_source.png`
- `assets/art/prerendered/m01_sunset_palms/courtyard_pixel_art_candidate.png`
- `assets/art/prerendered/m01_sunset_palms/courtyard_pixel_comparison.png`
- `assets/art/prerendered/m01_sunset_palms/layers/ground.png`
- `assets/art/prerendered/m01_sunset_palms/layers/architecture.png`
- `assets/art/prerendered/m01_sunset_palms/layers/props_vegetation.png`
- `assets/art/prerendered/m01_sunset_palms/layers/foreground_occlusion.png`
- `C:\tmp_shots\m01_gallery_current.png`
- `C:\tmp_shots\m01_prerender_layers_scale1.png`
- `C:\tmp_shots\m01_prerender_preview_alpha.png`
- `C:\tmp_shots\m01_pixel_candidate_gallery.png`
- `C:\tmp_shots\m01_ground_only_interactive.png`
- `C:\tmp_shots\m01_ground_only_alpha028.png`
- `C:\tmp_shots\m01_ground_only_player028.png`
- `C:\tmp_shots\m01_ground_only_2d_fallback_scale1.png`
- `C:\tmp_shots\m01_real_renderer_offset0.png`
- `C:\tmp_shots\m01_real_renderer_offset_neg80.png`
- `C:\tmp_shots\m01_real_renderer_offset_pos80.png`

## Decisão

`ground`/pool e `props_vegetation` têm leitura e alinhamento úteis como placa de
preview sobre a arquitetura existente. `architecture` ainda não passa o gate: as
alas do motel têm uma projeção diferente das paredes live. `foreground_occlusion`
fica reservado até a camada base estar aprovada, para não esconder personagens,
objetivos ou portas.

A captura `m01_ground_only_interactive.png`, com `GALLERY_PRERENDER_GROUND_ONLY=1`,
escala `0.333333` e alpha `0.42`, é a melhor evidência até agora para uma
composição híbrida: o solo e a piscina alinham-se de forma útil e deixam de
duplicar as palmeiras/props. Isto aprova apenas o sub-gate de alinhamento da base;
não aprova ainda a integração final, porque falta validar personagens em movimento,
portas, objetivos e contraste durante gameplay.

Foi ainda testado `m01_ground_only_alpha028.png` com a mesma escala e alpha `0.28`.
Esta versão conserva o alinhamento e reduz a coloração sobre o cenário live, sendo
o próximo candidato para uma captura de gameplay; continua preview-only.

O teste com a câmara centrada no jogador (`m01_ground_only_player028.png`) confirmou
que a captura de revisão não é ainda uma validação de contraste do elenco: o jogador
não ficou enquadrado de forma útil nesta posição inicial. É necessário ajustar o
probe/câmara ou capturar após o spawn estabilizar antes de aprovar a integração.

Para tornar essa revisão reproduzível, `tools/level_gallery.gd` agora aceita
`GALLERY_PLAYER_CELL=x,y` em modo de galeria; isto move apenas o jogador da captura
para uma célula de teste e não altera o nível guardado nem o runtime normal.
O diagnóstico confirma a posição `(328, 328)` e `visible=true`, mas o sprite continua
ausente; o próximo ajuste deve seguir o estado de animação/escala do `CharacterVisual`.
O fallback opt-in `GALLERY_PLAYER_FALLBACK=1` produz uma frame 2D visível em
`m01_ground_only_2d_fallback_scale1.png`, suficiente para validar contraste da
composição sem confundir essa prova com a integração da `ViewportTexture` 3D.
Comando de reprodução da prova de contraste:
`GALLERY_MISSION=m01_checkout GALLERY_PRERENDER=1 GALLERY_PRERENDER_GROUND_ONLY=1 GALLERY_PLAYER_CELL=20,20 GALLERY_PLAYER_FALLBACK=1`.
Para testar o crop sem alterar o nível, `GALLERY_PRERENDER_OFFSET=x,y` desloca a
placa em píxeis de ecrã relativamente ao centro `(464,296)`.
Uma captura no renderer real, `m01_real_renderer_offset0.png`, confirma que a
placa ground-only é visível sobre o pátio e que a frame de contraste do jogador
fica legível; continua a ser uma prova de revisão, porque usa o fallback 2D e
alpha reduzido.
Foi também testado `m01_real_renderer_offset_neg80.png` (`-80,-20`); o
deslocamento não melhora de forma inequívoca a relação piscina/portas, por isso
o crop base continua a ser o candidato de referência e nenhuma camada foi
integrada.
O teste oposto `m01_real_renderer_offset_pos80.png` (`+80,+20`) desloca as
reflexões e a faixa de estacionamento para fora das referências live; também foi
rejeitado. O centro `(464,296)` permanece o melhor ponto de revisão conhecido.
Em modo `--headless` o renderer dummy pode não fornecer imagem; a galeria agora
termina com aviso controlado nesse caso. As capturas visuais devem ser feitas no
editor/janela Godot com renderer real.


`courtyard_pixel_art_candidate.png` melhora a linguagem de pixels através de uma
paleta reduzida sem dithering, mas continua a ser uma variante de revisão. A
variante pode ser regenerada com `python tools/art/make_pixel_candidate.py`.
Antes da revisão visual, valide-a com `python tools/art/audit_pixel_candidate.py`.
Na comparação lado a lado, o candidato ganha clareza nos ladrilhos e no pool,
mas perde detalhe nas palmeiras e satura o neon; a próxima passagem deve proteger
os highlights emissivos e reservar mais tons escuros para a vegetação.

Nota de reprodução: o exportador de camadas precisa de abrir a cena Blender antes
de executar o script; chamar o script num Blender vazio cria PNGs transparentes.
Use:
`blender -b assets/art/prerendered/m01_sunset_palms/sunset_palms_courtyard.blend --python tools/art/render_motel_layers.py`
seguido de `python tools/art/audit_motel_layers.py`.
O exportador agora verifica a câmara `Courtyard master camera` e a presença de
malhas antes de escrever qualquer ficheiro.

## Gate para integrar

1. Ajustar a câmara/crop das alas ou decidir uma composição híbrida sem a camada
   `architecture`.
2. Capturar o M01 com personagens em movimento, colisões, portas e objetivos.
3. Confirmar contraste do elenco e ausência de oclusão indevida.
4. Executar `audit_motel_layers.py`, as auditorias gerais e o smoke test.

Até estes quatro pontos estarem confirmados, os PNGs permanecem em
`preview_only_not_integrated`.

## Estado atual do gate

- [x] Layers existem, têm RGBA, alpha não vazio e resolução comum.
- [x] Candidato pixel-art tem dimensões válidas, alpha e no máximo 96 cores.
- [x] Auditorias visuais, áudio, layout e smoke test conhecidos estão verdes.
- [x] Captura visual do candidato na câmara real do M01 concluída.
- [x] Sub-gate de alinhamento da base testado com captura interactiva ground-only.
- [ ] Crop/projeção das alas aprovado sem oclusão de personagens, portas ou objetivos.
- 2026-10-05: Sunset Palms layers regenerated and audited. `C:/tmp_shots/m01_layers_contact.jpg` and `C:/tmp_shots/m01_ground_latest.png` were visually inspected with the real Blender/Godot renderer. Ground/pool alignment is promising, but the layer remains staging-only until architecture/prop occlusion and walkable collision are tested together.
- Pixel comparison regenerated at `assets/art/prerendered/m01_sunset_palms/courtyard_pixel_comparison.png` and visually inspected. Master preserves the intended high-detail lighting and reflections; the 96-colour candidate is readable but loses fine facade/foliage detail when enlarged, so it remains review-only. Do not promote it to runtime until a higher-detail deliberate pixel pass is produced.
- Tested a separate 192-colour candidate `courtyard_pixel_art_candidate_hq.png` (187 RGB colours after quantization) and inspected `C:/tmp_shots/m01_pixel_hq_comparison.jpg`. It retains more facade and foliage detail than the 96-colour candidate, but the 480×270 source still softens fine edges; it remains staging-only and is not referenced by runtime.
- Higher-detail pixel pass validated: `tools/art/build_prerendered_motel.py -- --pixel_hq` now renders a 960×540 source, and `tools/art/make_pixel_candidate_hq.py` reduces it to a 192-colour nearest-neighbour 1920×1080 candidate. Visual inspection of `courtyard_pixel_art_candidate_hq.png` shows crisp pool tiling, balcony rails, foliage silhouettes and neon lettering with substantially less blur than the old 480×270 candidate. It remains staging-only until a live gameplay composition test passes.
- Real Godot composition test added via `GALLERY_PRERENDER_PIXEL_HQ=1`; capture `C:/tmp_shots/m01_pixel_hq_gallery.png` was visually inspected. The HQ plate is crisp, but the full plate currently ghosts against live architecture/props at the review crop and would obscure gameplay landmarks. It is therefore rejected for direct integration; retain it as art reference while layer-by-layer alignment is solved. The opt-in gallery flag remains review-only.
- Layer composition test `C:/tmp_shots/m01_ground_props_gallery.png` (real renderer, `GALLERY_PRERENDER_LAYERS=1`) was inspected. Pool/floor alignment remains usable, but props such as the sign, palms and car ghost against their live counterparts; do not integrate the combined layer. The approved route remains ground-only staging first, followed by explicit removal/replacement of duplicate runtime props.
- Ground-only contrast test at alpha 0.12: `C:/tmp_shots/m01_ground_alpha12.png`. Pool edge and wet pavement texture remain readable, live props/architecture stay dominant, and the player marker/body remains legible. This is the strongest overlay setting found, but it is still review-only because the plate's baked light pools would need to be reconciled with runtime lighting before integration.
- Runtime validation: fixed the freed-shooter hit-confirm check in `scripts/weapons/bullet_system.gd`; smoke test now completes with 0 failures and no freed-instance error. This is independent of the staging-only M01 art tests.

- 2026-10-05: regenerated courtyard_pixel_art_candidate_hq.png after reducing highlight compression from 0.45 to 0.70 in 	ools/art/make_pixel_candidate_hq.py. The 1920x1080 review plate preserves brighter neon/window highlights while retaining dark foliage separation; python tools/art/audit_pixel_candidate.py passes with 92 RGB colours. It remains preview-only and is not integrated into runtime.


- 2026-10-05: real-renderer isolation capture C:/tmp_shots/m01_ground_isolated.png using GALLERY_PRERENDER_GROUND_ONLY=1, GALLERY_PRERENDER_ISOLATE=1, player fallback and alpha 0.22. Pool/ground plate alignment is readable and the live player/interactive actors remain visible; residual rain/light FX are expected review overlays. No collision or gameplay behavior changed, and the plate remains preview-only.


- 2026-10-05: full HQ plate isolation capture C:/tmp_shots/m01_pixel_hq_isolated.png completed with GALLERY_PRERENDER_PIXEL_HQ=1 and GALLERY_PRERENDER_ISOLATE=1. The camera crop aligns the pool, parking lane, sign and palm silhouettes well enough for staging, while runtime actors/markers remain visible. Residual level FX/underlay show that direct full-plate integration would still alter gameplay readability; keep the HQ plate preview-only and prefer a ground/camera-matched hybrid.


- Added review-only 	ools/art/make_ground_review_variant.py and GALLERY_PRERENDER_GROUND_NO_EMISSIVE=1. Capture C:/tmp_shots/m01_ground_no_emissive.png confirms the softened ground layer preserves pool tiling/geometry while reducing baked light pools; live player/markers remain readable. This is a staging candidate only and is not imported by normal gameplay.


- Compared ground_no_emissive_review.png at alpha 0.12 in C:/tmp_shots/m01_ground_no_emissive_alpha12.png: baked glare is controlled, but the ground texture becomes too subdued under the live night grading. Keep alpha ~0.22-0.30 for review; do not promote the alpha-0.12 setting.


- Best current ground-only staging capture: C:/tmp_shots/m01_ground_no_emissive_alpha22.png. Alpha 0.22 preserves pool tile detail without overpowering live rain, actors or interactive markers; retain this as the review reference while integration remains gated.


- Added side-by-side comparison assets/art/prerendered/m01_sunset_palms/ground_review_comparison.png for the original versus no-emissive ground. It confirms geometry is unchanged and only the baked highlight range is softened; use it with the alpha-0.22 capture when reviewing integration.



- 2026-10-05: reinspeção de `assets/art/prerendered/m01_sunset_palms/ground_review_comparison.png` confirma que a variante no-emissive preserva piscina, grelha, estacionamento, sinal e manchas de desgaste, reduzindo apenas o bloom baked. Mantém-se adequada para staging, mas continua preview-only até validar oclusão com atores em movimento.


## 2026-10-05T21:40:28 — alpha22 capture gate

Reviewed `C:\tmp_shots\m01_ground_no_emissive_alpha22_latest.png` after the latest Godot import. The ground-only preview is correctly aligned and preserves the pool/pavement landmarks, but at the current gallery compositing it is too dark and shows visible chromatic/fringe artifacts around the emissive props. It remains **preview-only** and is rejected for integration until a brighter, cleanly composited capture passes character/objective readability and occlusion review.


## 2026-10-05T21:41:50 — clean preview review mode

Added opt-in `GALLERY_CLEAN=1` handling in `tools/level_gallery.gd`. It hides only the post-process CRT layer and darkness overlay and restores the level ambient modulate for asset review, leaving normal gameplay untouched. This is intended to produce a clean value/occlusion capture before the Sunset Palms plate gate. Godot editor import/parse and `git diff --check` pass.


## 2026-10-05T21:43:49 — clean alpha32 capture review

Generated `C:\tmp_shots\m01_ground_clean_alpha32_v2.png` with `GALLERY_CLEAN=1`. Neutralising the gallery ambient removes the severe black/purple crush and makes pool geometry and pavement seams readable. The capture still contains intentional production weather/lighting and high-contrast live props, so it is suitable for alignment review but not yet sufficient as a final integrated backdrop. Keep the Blender layer preview-only pending a final occlusion/readability pass.


## 2026-10-05T21:45:04 — clean alpha32 v3

Generated `C:\tmp_shots\m01_ground_clean_alpha32_v3.png` with weather hidden in clean review mode. This removes rain noise and confirms the plate alignment/occlusion landmarks, but the production red light pool remains visible by design. The layer is still not promoted to runtime integration; next gate is readability with the intended live player/objectives over this neutral review.


## 2026-10-05T21:47:52 — live composition gate rejected

Reviewed `C:\tmp_shots\m01_ground_clean_live_alpha22.png` with live art and player visible. The ground plate is aligned, but the combined composition is overexposed and duplicate pool/prop landmarks compete with gameplay silhouettes. This is a useful negative gate: do not integrate the plate into normal runtime yet. Keep the plate isolated/preview-only and resolve lighting/duplicate landmark ownership first.


## 2026-10-05T21:50:09 — no-pool staging export

Added preview-only `layers/ground_no_pool_review.png` from the Blender exporter and an opt-in `GALLERY_PRERENDER_GROUND_NO_POOL=1` selector. The live composition capture `C:\tmp_shots\m01_ground_no_pool_live.png` confirms pool duplication is reduced, but the white clean-review ambient still overexposes live art; this variant is therefore staging-only and not integrated. It remains useful for isolating pavement ownership in the next lighting pass.


## 2026-10-05T21:51:19 — production-grade clean mode

Changed `GALLERY_CLEAN=1` to preserve the level's production ambient by default; `GALLERY_CLEAN_NEUTRAL=1` is now required for raw white texture inspection. Generated `C:\tmp_shots\m01_ground_no_pool_production_grade.png`; the scene keeps readable contrast without the earlier white wash, while preserving the live pool and lighting. The new no-pool layer remains a staging aid and is not integrated.


## 2026-10-05T21:52:20 — low-alpha no-pool composition

Generated `C:\tmp_shots\m01_ground_no_pool_production_alpha12.png` at alpha 0.12 with the production ambient preserved. The pavement overlay is subtle and the live pool remains the sole pool landmark, but the preview still needs a deliberate final lighting/occlusion approval before runtime integration. No gameplay assets were changed.


## 2026-10-05T21:55:06 — variant contact sheet

Created `C:\tmp_shots\m01_prerender_variants_contact.png` comparing clean alpha32, no-pool alpha32, and no-pool alpha12. The alpha12 no-pool variant has the best gameplay readability and avoids a duplicate pool landmark, but its magenta production light still needs an explicit lighting ownership decision. No variant is promoted to runtime.


## 2026-10-05T21:56:37 — neutral colour staging variant

Generated `ground_no_pool_neutral_review.png` and tested it through `GALLERY_PRERENDER_GROUND_NEUTRAL=1` at alpha 0.16 (`C:\tmp_shots\m01_ground_neutral_alpha16.png`). It suppresses some baked magenta saturation without changing runtime art, but the improvement is subtle at gameplay alpha. Keep it as an optional staging variant; no integration decision is made.


## 2026-10-05T22:02:42 — neutral render from Blender lights

Updated `tools/art/render_motel_layers.py` so `ground_no_pool_neutral_review.png` is rendered with Blender LIGHT objects disabled, rather than post-process colour correction. Blender export, the expanded layer audit, Python compile, and Godot reimport all pass. The neutral pass is still staging-only; it did not remove the level's magenta live lighting and is not integrated.
- Fixed a gallery-only selector bug in `tools/level_gallery.gd`: `GALLERY_PRERENDER_GROUND_NEUTRAL=1` now selects `ground_no_pool_neutral_review.png`, while `GALLERY_PRERENDER_GROUND_NO_POOL=1` selects `ground_no_pool_review.png`. Godot editor import and full smoke test remain clean (`0 failures`); runtime gameplay is unchanged.

## 2026-10-05 — lighting ownership isolation

Added opt-in `GALLERY_MUTE_MAGENTA_LIGHTS=1` to `tools/level_gallery.gd`. It hides only magenta `LightFixture` nodes in the gallery review, leaving normal runtime lighting and gameplay untouched. M01 gallery load with the no-pool staging layer completed without script/parse errors; headless mode correctly skipped visual capture. Use this pass to judge plate readability separately from the live exterior mood lights.

## 2026-10-05 — refreshed pixel comparison

Regenerated `assets/art/prerendered/m01_sunset_palms/courtyard_pixel_comparison.png` from the current Blender master and candidate. Geometry landmarks remain aligned, but the candidate still introduces overbright magenta bloom and loses dark architectural separation around the left facade and palms. Keep it preview-only; do not integrate the full candidate plate.

## 2026-10-05 — soft HQ candidate

Created `courtyard_pixel_art_candidate_hq_soft_review.png` as a separate review variant (highlight compression 0.55, no colour boost, 192 colours). It restores facade/palm separation compared with the current HQ candidate while retaining pool/sign landmarks. It remains review-only; the existing candidate and runtime are unchanged pending visual approval.

## 2026-10-05 — candidate contact review

The three-way contact sheet `courtyard_pixel_candidates_contact.png` confirms the soft variant reduces highlight clipping slightly, but both HQ candidates retain the same magenta road bloom and would still compete with live gameplay silhouettes. Keep both preview-only; no runtime promotion.

- Added a runtime-isolation assertion to `tools/art/audit_motel_layers.py`: scripts, levels and scenes are scanned for accidental `assets/art/prerendered` references. Current audit passes, confirming all plates remain gallery/staging-only.

## Current gate recommendation

For the next visual approval pass, use `ground_no_pool_review.png` at low gallery alpha (about 0.12) with production ambient preserved. It avoids a duplicate pool landmark and keeps the live level readable. The full plate, HQ candidates, and neutral pass remain rejected for runtime promotion until the live composition is reviewed with actors/objectives visible.

## 2026-10-05 — approved M01 ground integration

Visual approval received for the low-alpha no-pool composition. Integrated `ground_no_pool_review.png` only in M01 (`scripts/levels/level.gd`) at alpha 0.12, scale 0.333333 and z-index -30. The live pool, actors, props, collision and objectives remain authoritative. The audit explicitly allows this single approved reference and rejects all other runtime prerender references. Godot import and full smoke test pass with `0 failures`.
- Added smoke-test coverage for the approved plate: M01 must contain `ApprovedM01GroundPlate`, while M02 must not. The new assertions pass in the full smoke run (`0 failures`).
## Latest verification (2026-10-06)

- Blender interior staging: 385 objects / 12 materials after reception and service prop pass.
- `audit_m01_staging.py`: PASS.
- `audit_m01_runtime_isolation.py`: PASS.
- Full Godot smoke (`res://tools/smoke_test.tscn`): 0 failures for M01 + M02.
- Runtime promotion remains held until the interior art reaches the exterior master quality bar.

## 2026-10-06 — material/detail pass

Blender staging received micro-bump material response and additional authored interior props (framed art, towel stacks, reception wall art). The three staging renders were regenerated. Staging, runtime-isolation and 4K audits pass, and the full Godot smoke test completes with 0 failures. Interiors remain staging-only because their current visual finish still needs to reach the approved Sunset Palms pool courtyard bar before promotion.
- Latest Blender staging scene inspection: 385 objects and 12 materials.
- Camera refinement: reception/service detail renders were regenerated with a higher oblique 3/4 camera. This improves floor/readability balance and keeps the assets staging-only pending the visual gate.
- Added authored interior door kits with inset panels, handles and color-coded signs; renders remain staging-only and audits pass.
- Added controlled wear clusters and notice decals at non-critical floor/wall landmarks; staging remains review-only and audits pass.
- Added emissive Blender text signage to the reception staging scene; remains review-only.
- Added exposed conduit runs and clamps to the service zone; still staging-only and audits pass.
- Global regression validation: visual/audio/layout/PixelLab audits pass; full Godot smoke completes with 0 failures after the staging-only Blender updates.
- Added hotel room fixture kit (AC vents and luggage racks) to both guest-room zones; remains staging-only.



- Added opt-in 4K Blender interior render path; three 3840x2160 review renders are available under staging/4k/, with no runtime promotion.
- Added and ran udit_m01_interior_4k.py: PASS for all three 3840x2160 interior renders.
- 4K visual gate review confirms clean geometry/material response but insufficient prop density versus the pool courtyard; this is an explicit promotion blocker, not a hidden quality issue.
- Added luggage trolley and labeled fire extinguisher to reception staging; remains review-only.
- Added service-zone shelving, linen bundles and floor drains; remains staging-only.
- Added service runner and safety-floor markings to the laundry staging zone; remains review-only.
- Refreshed the optional 4K interior renders after the latest prop pass; 4K audit remains PASS.
- Added bathroom nook kits to both guest-room variants and refreshed standard/4K staging renders; no runtime promotion.
- Added AC conduit runs to both guest rooms and refreshed standard previews; 4K review remains available from the preceding approved render pass.
- Global prerender contract audit passes; all new interior outputs remain staging-only.

- 2026-10-06 verification: visual quality and prerender contract audits remain PASS; promotion gate unchanged.
- Added alternating floor inlay strips across M01 room kits for material variation; staging-only.

- 2026-10-06: Added a continuous architectural plinth and recessed transition strips to the M01 interior staging composition. This resolves the floating-room presentation problem without changing runtime navigation or collision. Standard/pixel renders and staging/isolation audits pass; promotion remains held for visual approval.

- Layout fidelity rule: all Blender upgrades must preserve the original Godot level footprint, routes, collision and encounter pacing. Blender owns the visual layer; Godot remains authoritative for gameplay geometry and navigation.

- 2026-10-06 — architectural base readability pass: the staging-only plinth joining the four interior zones was lifted slightly from near-black blue to a readable midnight-blue value. Standard, pixel and 4K renders were regenerated; no runtime plate, layout, collision or navigation data changed.
- 2026-10-06 — staging ambient pass: raised only the Blender world's cool ambient level so the plinth and transition seams remain legible around the rooms. Standard and pixel previews were regenerated and passed staging/isolation audits; runtime lighting and assets are unchanged.
- 2026-10-06 — Eevee shadow-budget pass: disabled shadows only on low-energy secondary staging lights (<140) to prevent shadow-atlas overflow while retaining key practical shadows. Standard, pixel and 4K renders were regenerated; runtime lighting is untouched.
- 2026-10-06 — corridor dressing pass: added three overhead service spines with conduit runs and small status indicators. They sit above the playable lane and are staging-only; standard/pixel renders and Blender isolation audits pass.
- 2026-10-06 — contract recheck: Pixel candidate, motel layer and audio reference audits all pass after the corridor pass; no runtime prerender references were introduced.
- 2026-10-06 — review contact sheet: combined the full M01 interior map, reception detail and service-transition detail in `assets/art/prerendered/m01_sunset_palms/staging/m01_blender_review_contact.png` for one-pass visual approval.
- 2026-10-06 — 4K review contact sheet: added `assets/art/prerendered/m01_sunset_palms/staging/m01_blender_review_contact_4k.png`, assembled from the three 3840×2160 outputs; visual inspection confirms consistent lighting and no new intersection.
- 2026-10-06 — full-level review sheet: assembled the exterior master and the 4K interior staging contact into `assets/art/prerendered/m01_sunset_palms/m01_full_level_review.png` for composition review. Exterior remains the approved runtime reference; interiors remain staging-only.
- 2026-10-06 — layout alignment diagram: generated `assets/art/prerendered/m01_sunset_palms/m01_layout_alignment_review.png` directly from `levels/m01_sunset_palms.json`. It records the shared footprint and the Blender zone mapping; no gameplay geometry was changed.
- 2026-10-06 — regression verification: reran the M01 Blender staging audit and the three-render 4K audit, followed by the complete Godot smoke test for M01/M02. All checks passed; smoke test finished with 0 failures. The environmental-motion grammar remains documented for the final composed scene and future levels; no runtime composition or gameplay geometry was changed.
- 2026-10-06 — environmental destruction pass: documented Blender treatment for the existing M01 destructibles (TVs, arcades, vending machines, lamps, plants, fuse boxes, windows, weak walls and propane tanks). The Godot layer already handles their damage states; the visual pass adds cracks, debris, sparks, smoke, scorch and emergency-light cues without changing collision or navigation.
- 2026-10-06 — breakable-prop readability pass: broken TVs now render a multi-fracture CRT star, arcades show a damaged screen with intermittent sparks, and vending machines retain visible jagged glass fragments. The full smoke test covers the new TV break path and finishes with 0 failures.
- 2026-10-06 — destruction regression coverage: smoke test now exercises TV, arcade and vending break states independently with ballistic damage. M01/M02 gameplay, boss, escape and save/load checks remain at 0 failures.
- 2026-10-06 — plant break readability: overturned plants now retain a low-profile soil patch and scattered leaf silhouettes after impact; the decoration remains outside navigation and collision.
- 2026-10-06 — service-density pass: added authored detergent boxes, bottles, stacked baskets and damp floor patches to the Blender laundry transition. Regenerated standard and 4K renders; moved the final 4K shadow-budget switch after all lights are created, eliminating shadow-buffer overflow. Staging and 4K audits pass.
- 2026-10-06 — guest-room dressing pass: added Meshy TV dressers, suitcase piles and bedside lamps to both guest-room variants, keeping the central circulation clear. Standard and 4K staging renders regenerated; Blender and 4K audits pass.
- 2026-10-06 — reception dressing pass: added the Meshy key rack, luggage cart and water cooler to the lobby, keeping the sofa and approach lanes clear. Standard and 4K renders regenerated; Blender and 4K audits pass.
- 2026-10-06 global regression checkpoint: visual quality audit reports 217 sprites / 300 decor entries / 91 pixel shots with zero missing imports, empty alpha, oversized assets or missing shots; audio references 38/38; M01-M04 layout reachability passes; M01 pixel candidate remains valid at 1920x1080 with 92 RGB colours.
- 2026-10-06 cutscene/UI checkpoint: regenerated six contact sheets from the current used-shot manifest; page 01 visual review shows coherent shot coverage (apartment, Arlo, Cass, Barstow, control room and establishing shots). Global visual audit remains zero missing shots/imports.
- 2026-10-06 — repaired `tools/level_gallery.gd` so the gallery resolves autoloads through `/root` when invoked as a project scene; direct `--script` usage now fails clearly while the supported scene invocation loads M01 successfully. Headless scene run completed with M01 prewarm (23 looks); capture is skipped only because the renderer is headless.
- 2026-10-06 — added runtime smoke coverage for ambient visual motion: M01 now asserts that an `AnimatedProp` is instantiated and its position changes over 24 physics frames. Full M01/M02 smoke remains `0 failures`.
- 2026-10-06 — transition-floor readability pass: raised the blue-gray/emissive response of the staging surround floor so the architectural plinth reads continuously around the room modules. Blender staging, isolation and layer audits pass; runtime remains unchanged.
- 2026-10-06 — transition paving detail pass: added cross-joints, trim insets and drainage markers to the staging plinth; no runtime geometry or layout changed.

- 2026-10-06 — plinth readability pass (Codex): raised the staging-only architectural plinth to a readable midnight-blue value with restrained emission, removing the near-black void between interior modules. Standard staging renders regenerated; Godot geometry and runtime layers unchanged.

- 2026-10-06 — entrance composition pass: added a staging-only wet access lane with centered gate posts, raised barrier arms and amber beacons, then rebuilt m01_full_level_review_current.png so the exterior, entrance, interior layout, reception and service areas are reviewed together. Runtime layout, collisions and navigation are unchanged.

- 2026-10-06 — arrival-detail pass: added two reflective bollards and worn lane chevrons to the staging-only entrance approach. Re-rendered the courtyard and entrance review, then refreshed the full-level composition sheet; gameplay and runtime layer contracts remain unchanged.

- 2026-10-06 — composition checkpoint: the current review sheet is the authoritative visual reference for the whole M01 staging pass (courtyard/pool, entrance approach, interior footprint, reception and service/laundry). Future detail passes must preserve these landmarks and the original gameplay footprint.

- 2026-10-06 — 4K entrance review: added the opt-in M01_APPROACH_4K=1 render path and generated ntrance_approach_detail_staging_4k.png at 3840×2160. This is staging-only and uses the same gameplay-preserving approach geometry.

- 2026-10-06 — interior maintenance-detail pass: added three restrained exposed drain elbows with cyan condensation drops and floor puddles to the shared walkway. They remain outside the playable centerline; 4K renders and staging/runtime-isolation audits pass.
- 2026-10-06 — arrival readability pass: added restrained amber gate-post lights and cool lane markers to the staging-only entrance render. The gate, barrier arms and car approach remain unchanged; staging and runtime-isolation audits pass.
- 2026-10-06 — refreshed `m01_full_level_review_current.png` after the arrival readability pass so the authoritative composition sheet includes the latest 4K entrance render.
- 2026-10-06 — Godot 4.7.2 validation checkpoint: full smoke (M01/M02), chapter 3/4 suite, edge suite and stress suite completed with exit code 0 and zero reported failures. No executable export was produced; visual promotion remains approval-gated.
- 2026-10-06 — M01 gallery load checkpoint: `res://tools/level_gallery.tscn` opened `m01_checkout` headlessly with exit code 0; capture was skipped only because the renderer is headless.
- 2026-10-06 — Blender-only interiors pass: disabled external GLB prop promotion in `build_m01_interiors.py`; props now use authored Blender geometry/fallbacks for staging. 4K interior and staging audits pass; Godot runtime assets/layout remain unchanged.
- 2026-10-06 — Blender-only exterior pass: disabled GLB vehicle promotion in `build_prerendered_motel.py`; the courtyard review now uses native Blender vehicle geometry while preserving the car-arrival composition. M01 staging and runtime-isolation audits pass.
- 2026-10-06 — guest-room identity pass: separated the two rooms with clearly different warm/floral and cool/teal palettes, bedding, carpets, wall art and travel props. Doorways, room footprints and playable circulation are unchanged; interior 4K/staging audits pass.
- 2026-10-06 — entrance review framing pass: extended only the Blender staging road surface and tightened the review crop so the gate posts, barriers, wet lane and arrival vehicles occupy the frame. The original Godot entrance footprint, car route, collisions and camera contract are unchanged; refreshed `m01_full_level_review_current.png`.
- 2026-10-06 — cross-level regression checkpoint: chapter 3 suite completed with `=== CHAPTER 3 TEST DONE: 0 failures ===`, covering all story scenes, M03, M04, arcade waves and weather presets. No runtime visual promotion or EXE export was performed.
- 2026-10-06 — made the entrance review crop reproducible with `tools/art/crop_entrance_review.py`; it only post-processes the optional 4K staging image and cannot affect Godot runtime assets.
- 2026-10-06 — evento ambiental raro validado: durante estados de chuva/trovoada, o `AmbientEventDirector` pode atingir uma palmeira uma única vez por sessão do nível. A copa incendeia por ~12 s, recebe luz e áudio de trovão, e é removida visualmente no fim; colisões, navegação e objetivos não são alterados. Os relâmpagos seguintes permanecem apenas como atmosfera meteorológica.
- 2026-10-06 — regenerated the Blender-only M01 interior staging at 3840×2160 after the reception/sofa and clipping fixes. The three 4K renders and staging package pass `audit_m01_interior_4k.py` and `audit_m01_staging.py`; runtime integration remains unchanged.
- 2026-10-06 — visual inspection of the regenerated 4K reception pass confirms the sofa back faces the camera, the seating is separated, and no right-edge prop clipping is visible. Ceiling sockets and strong practical-light pools remain intentional staging details for the final composition pass.
- 2026-10-06 — full-level contact review confirms the Blender staging footprint matches the gameplay layout across exterior, entrance, rooms, reception and service. The next quality pass is concentrated on interior prop density/material variation; no runtime promotion is approved yet.
- 2026-10-06 — lavanderia density pass: added three folded-towel piles and a restrained damp-floor trail at the service edges. The central transition remains clear; regenerated 4K staging passes `audit_m01_interior_4k.py`.
