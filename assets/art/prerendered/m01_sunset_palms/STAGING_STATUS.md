# M01 Sunset Palms — Blender staging status

## Approved evidence
- Exterior Blender scene: `sunset_palms_courtyard.blend`.
- Runtime ground plate: `layers/ground_no_pool_review.png`, integrated at low alpha.
- Gameplay smoke: `res://tools/smoke_test.tscn` completes with 0 failures.
- Layout audit: all M01 entities reachable; no single-exit rooms.
- Visual/audio asset audits pass.

## Staging only
- `staging/m01_interiors_transitions_staging.blend`
- `staging/m01_interiors_transitions_staging.png`
- `staging/m01_reception_detail_staging.png`

These renders prove zone coverage and camera direction, but are not final art. The full map must reach the detail bar in `ART_DIRECTION.md` before promotion.

Visual gate decision: **hold promotion**. The new floor seams and wall architecture improve room readability, but the reception and service close-ups still need authored clutter/signage and stronger material variation to match the exterior master and the requested reference quality.

Next Blender pass is limited to the reception/service zones: readable motel signage, key hooks/mail slots, laundry labels/pipe joints, decals, and small contact-shadow props. After that pass, inspect at 100% and rerun the staging and runtime-isolation audits before considering a one-zone Godot integration.

## Promotion gates
1. Render each interior and transition at 3/4 oblique camera with authored props and material variation.
2. Compare each render against the 68x61 M01 gameplay grid and reserve combat lanes around doors, objectives and exits.
3. Check foreground/midground/background readability at 100% scale, before CRT/weather grading.
4. Integrate one zone at a time and rerun M01 smoke plus layout audit after each promotion.
5. Keep trailer paused and never generate an EXE during this process.

## Latest verification snapshot
- Visual audit: 217 sprites, 300 decor entries, 91 pixel shots, zero missing imports/alpha/oversized assets.
- Audio audit: 38 references, zero missing.
- Layout audit: M01 19 regions; all entities reachable; no single-exit rooms.
- Gameplay smoke: `=== SMOKE TEST DONE: 0 failures ===` for M01 + M02 path.
- Latest full smoke rerun after the interior Blender pass: `=== SMOKE TEST DONE: 0 failures ===`.
- Runtime isolation: `M01 runtime isolation audit: PASS`.
- Godot headless editor reimported all four staging PNG outputs successfully after the pixel-preview pass.
- Blender staging scene inspection: 385 total objects after the latest detail pass.
- Blender staging load validation: 385 objects and 12 materials loaded successfully.

- Pixel-preview contact sheet generated: staging/m01_pixel_previews_contact.png (1280x800).
- Exterior courtyard Blender inspection: 142 objects, 56 materials, 78 lights.
- Trailer/export guard verified: only opt-in `AUTOPLAY_TRAILER=1` paths set trailer metadata; no trailer capture or EXE generation was run during this art pass.
- 4K layer pass generated with `M01_RENDER_4K=1`: six RGBA layers at 3840x2160 under `layers/4k/`; runtime 1920x1080 layers were left untouched.
- `tools/art/audit_m01_4k_layers.py` validates all six 4K layers; current result: `PASS`.
- Reception staging received a detail pass with visible monitor, base, bell, ledger and key board; renders/previews regenerated and staging audit remains `PASS`.
- Service transition staging received visible pipework, cart handle and detergent bottles; renders/previews regenerated and staging audit remains `PASS`.
- Guest-room staging received wall art, minibar and vase accents across the duplicated room kit; renders/previews regenerated and staging audit remains `PASS`.
### 2026-10-05 interior detail pass

- Re-rendered the Blender-only M01 interior staging after adding modular floor seams, contrasting floor border, wall dado/cap rails, and vertical pilasters to the guest, laundry, and reception rooms.
- `audit_m01_staging.py` and `audit_m01_runtime_isolation.py` pass. These remain review-only staging renders; no runtime promotion was performed.
- Final contact-sheet review after the reception/service prop pass confirms no layer isolation regressions; promotion remains intentionally held until the interior density matches the exterior master.
- Blender staging scene rechecked after the latest props: 385 objects and 12 materials; no runtime files were changed.
- Runtime ambient pass verified: pool water uses `PoolFX`, while `motel_pool_float` and `motel_pool_float_flamingo` use `AnimatedProp` for slow bob/drift; these nodes do not alter collision, navigation, or objective logic.
- Exterior master render visually rechecked at full resolution: pool edge, parking lanes, neon sign, palms, balcony rails, wet pavement and lighting read coherently; the pixel preview is intentionally a reduced review proxy, while the 4K layer set remains available for high-resolution export.
### 2026-10-06 material/detail pass

- Added procedural micro-bump material response to wall, floor, wood, metal and tile materials, plus authored framed art, towel stacks and reception wall art in the Blender staging builder.
- Re-rendered all M01 interior staging views with Blender; visual detail is improved but still remains review-only until it reaches the exterior pool master bar.
- `audit_m01_staging.py`: PASS; `audit_m01_runtime_isolation.py`: PASS; `audit_m01_4k_layers.py`: PASS.
- Full Godot smoke via `res://tools/smoke_test.tscn`: `=== SMOKE TEST DONE: 0 failures ===` (M01 + M02).
- No runtime promotion, trailer capture, or EXE generation performed.
- Latest Blender staging scene inspection: 385 objects and 12 materials after the material/detail pass.
- Camera refinement: reception and service close-ups now use a higher oblique 3/4 Blender camera to preserve playable floor readability while exposing ceiling fixtures and authored wall props. Pixel previews regenerated; staging and runtime-isolation audits remain PASS.
- Added authored interior door kits with inset panels, handles, labels and color-coded signs for guest/service circulation; Blender render and pixel previews regenerated; staging/runtime-isolation audits PASS.
- Added controlled wear clusters and notice decals to guest, laundry and reception zones; renders/previews regenerated and both staging/isolation audits PASS.
- Added emissive Blender text signage (SUNSET PALMS) to the reception staging scene; render/previews and audits regenerated; no runtime promotion.
- Added exposed conduit runs and clamps to the service zone for technical detail and material contrast; Blender render/previews regenerated; staging and runtime-isolation audits PASS.
- Global validation after latest staging pass: visual audit 217 sprites/300 decor/91 pixel shots with zero missing; audio 38/38; layout all M01-M04 reachable; PixelLab M01 candidate PASS; full Godot smoke 0 failures.
- Added hotel room fixtures (air-conditioner vents, luggage racks and legs) to both guest-room kits; Blender renders/previews and staging/isolation audits PASS.


- Added opt-in M01_INTERIOR_4K=1 render path; generated three 3840x2160 interior staging renders under staging/4k/. Runtime 1920x1080 layers remain untouched.
- New 	ools/art/audit_m01_interior_4k.py validates all three optional interior renders: PASS (3840x2160).
- 4K visual gate review: geometry/material response is clean and readable, but the enlarged render still exposes lower prop density than the approved pool courtyard; promotion remains held pending another authored-detail pass.
- Added reception props: luggage trolley with wheels/handle and fire extinguisher with label; staging renders/previews and audits PASS.
- Added laundry shelf rails, folded linen bundles and floor drains to the service zone; renders/previews and staging/isolation audits PASS.
- Added service runner and angled safety-floor markings to the laundry zone; regenerated renders/previews; staging/isolation audits PASS.
- Regenerated optional 4K interior renders after the latest lobby/laundry prop additions; udit_m01_interior_4k.py: PASS.
- Added bathroom nook kits (vanity, basin, mirror, towel rail) to both guest-room variants; standard and 4K renders refreshed; all staging audits PASS.
- Added AC conduit runs to both guest rooms, then regenerated standard renders/previews; staging/isolation audits PASS.
- Global prerender contract audit: udit_motel_layers.py PASS; only the approved low-alpha M01 ground plate is runtime-visible.

- 2026-10-06 verification: visual quality audit and prerender contract audit remain PASS; no runtime promotion decision changed.
- Added alternating floor inlay strips to all M01 room kits to break flat tile repetition; renders/previews and staging/isolation audits PASS.

### 2026-10-06 — density correction pass (Codex)
- Rejected the previous Claude visual gate: the rooms read as large empty planes compared with the approved Sunset Palms courtyard.
- Added authored micro-props in Blender staging: suitcase contents, desk tray/glasses/remote, shoes and magazines, wall phone; laundry detergent bottles, drying rack, drain and electrical panel; reception stationery, brochure stand and umbrella bucket.
- Re-rendered the master, reception and service close-up plus pixel previews/contact sheet.
- Validation: Python compile, Blender staging audit and runtime-isolation audit PASS; `git diff --check` clean. No runtime integration made.
- Gate remains staging-only pending another 100% visual review against the courtyard density bar.

### 2026-10-06 — coherent staging map pass (Codex)
- The previous wide render left rooms floating on black. Added a continuous Blender architectural plinth, recessed transition strips and perimeter coping so the interiors read as one Sunset Palms floor plan while preserving each room's clear playable footprint.
- Regenerated standard renders, pixel previews and contact sheet.
- Staging and runtime-isolation audits PASS; `git diff --check` clean. Runtime remains unchanged and staging-only.

### 2026-10-06 — layout fidelity constraint
- Confirmed design rule: Blender replaces/augments the visual treatment only; the original Godot level layout, navigation, collision, encounter spaces, objective routes and gameplay pacing remain authoritative.
- The architectural plinth is a staging backdrop and does not alter Godot geometry or runtime collision. Any promoted art must be aligned to the existing level landmarks and verified in a live composition pass.

### 2026-10-06 — reception occlusion fix (Codex)
- Visual review caught the Meshy lobby sofa intersecting the left wall. Reduced its staging width from 1.9 to 1.45 and moved it inward while preserving the reception layout and playable circulation.
- Regenerated standard/preview renders; staging and runtime-isolation audits PASS. No runtime geometry changed.

### 2026-10-06 — M01 validation checkpoint
- Re-ran Blender staging, optional 4K interior, runtime-isolation, and motel-layer audits: all PASS.
- Completed full Godot headless smoke test across M01 and M02: `=== SMOKE TEST DONE: 0 failures ===`.
- Visual QA confirms the unified interior staging composition reads as one authored floor plan; reception, service transition, guest rooms, and circulation remain separated from runtime geometry.
- No promotion of interior staging to runtime was made; the approved M01 ground plate remains the only interior-adjacent visual layer in live Godot until a landmark-alignment pass is reviewed.

### 2026-10-06 — transition-floor readability pass (Codex)
- Raised the staging surround floor's blue-gray base and emission so the architectural plinth reads continuously around the room modules without becoming a runtime surface.
- Regenerated Blender master, close-ups and pixel previews.
- Validation: Blender staging audit, runtime-isolation audit, motel-layer audit and `git diff --check` PASS. Runtime promotion remains held.

### 2026-10-06 — transition paving detail pass (Codex)
- Added subtle cross-joints, trim insets and drainage markers to the Blender staging plinth between interior modules, keeping the central corridor readable and non-colliding.
- Regenerated all staging renders/previews; visual review confirms improved continuity. Staging and runtime-isolation audits PASS; no runtime integration.

### 2026-10-06 — plinth readability pass (Codex)

- Lifted the staging-only architectural plinth from near-black to a readable midnight-blue material with restrained emission, so the gaps between room modules read as a connected Sunset Palms floor plan.
- Regenerated standard staging renders; the change is visual-only and does not modify Godot collision, navigation, layout or runtime layers.

- 2026-10-06 — entrance staging refresh: centered gate posts, raised barrier arms, amber beacons, reflective bollards and worn lane chevrons now complete the arrival approach review. The full-level sheet was refreshed; no gameplay or runtime geometry changed.

- 2026-10-06 — entrance detail is now available as an opt-in 3840×2160 staging render (ntrance_approach_detail_staging_4k.png) for the same visual-quality gate used by the interior passes.

- 2026-10-06 — added small drain/condensation details to the shared interior walkway for authored density; rendered in 4K and retained staging-only.
- 2026-10-06 — arrival readability pass: added restrained amber gate-post lights and cool lane markers to the staging-only entrance render; gameplay route and runtime integration remain unchanged.

### 2026-10-08 — guest-room bathroom fixture refinement (Codex)
- Generated `staging/guest_room_composition_v10`: the bathroom bay now has a lit vanity/mirror wall, faucet, shower panel, towel rail and fixture detail while the open room route remains visible.
- Regenerated the 0 and 30 degree camera comparison from v10 under `staging/guest_room_camera_review_v4` with measured ground-projection probes.
- Validation: guest-room staging audit, runtime-isolation audit, room-fit audit and general Blender staging audit PASS.
- v10 remains staging-only. Exact gameplay projection, actor occlusion, and live bathroom/entry clearance still gate promotion.

### 2026-10-08 — M01 ice-machine runtime replacement (Codex)
- Added the M01-only `runtime/ice_machine_v1` intact machine visual and its runtime contract. It overlays the two live `BreakableProp` ice-machine placements without changing their collision, health, sound, navigation, or damaged drawing.
- `tools/m01_ice_machine_review.tscn` validates both placements, transparent source texture, preserved PROP-layer collision, and the damage transition that hides the intact overlay and restores the existing broken state.
- Windowed runtime capture: `build/m01_ice_machine_runtime.png`; review evidence: `build/m01_ice_machine_runtime_review.json`.

### 2026-10-08 — M01 towel-cart runtime replacement (Codex)
- Added `runtime/towel_cart_v1`: a detailed overhead housekeeping-cart visual over the eight existing `motel_towel_cart` decor anchors.
- The native overlay preserves the authored transform and adds no collision, navigation reservation or interaction state. The former low-detail source sprite remains as a hidden transform anchor.
- `tools/m01_towel_cart_review.tscn` validates all eight placements, texture presence, hidden former sprite and zero added collision. Windowed capture: `build/m01_towel_cart_runtime.png`; review evidence: `build/m01_towel_cart_runtime_review.json`.

### 2026-10-08 — bedside-lamp runtime gate (Codex)
- Tested the existing generated `guest_room_props_v1/bedside_lamp_game.png` over the eight live bedside-lamp anchors without changing their LightFixture behavior or collision.
- Rejected the promotion after windowed review: at the runtime camera it read as oversized circular floor light rather than a bedside lamp. The experiment was removed; live M01 continues using the previous lamp visual.

### 2026-10-08 — M01 bedside-lamp runtime replacement (Codex)
- Replaced the rejected circular lamp candidate with `runtime/bedside_lamp_v2`: a high-angle shade/stem/base silhouette that reads as a bedside lamp at the live gameplay camera.
- The M01-only overlay is attached to the eight existing `motel_bedside_lamp` anchors, retaining their existing LightFixture behavior and adding no collision, pathing or interaction state.
- Runtime guest-room review verifies all eight overlays; windowed evidence: `build/m01_guest_room_accents_runtime.png` and `build/m01_guest_room_accents_runtime_review.json`.

### 2026-10-08 — M01 telephone runtime replacement (Codex)
- Added `runtime/telephone_v1` over the two visual-only `motel_telephone` decor anchors. The new handset/keypad/cord silhouette is verified in `build/m01_telephone_runtime.png`; collision and navigation remain unchanged.
- `tools/m01_telephone_review.tscn` passes both placements. Full M01/M02 smoke: `0 failures`.

### 2026-10-08 — M01 open-suitcase runtime replacement (Codex)
- Added `runtime/open_suitcase_v1` to the three `motel_suitcase_open` guest-room floor anchors, introducing readable clothing, sunglasses, paperback and key dressing.
- The overlay preserves the original floor anchor transforms and adds no collision, navigation reservation or interaction state. Focused validation: `tools/m01_open_suitcase_review.tscn`; windowed evidence: `build/m01_open_suitcase_runtime.png`.

### 2026-10-08 — M01 vending-machine runtime replacement (Codex)
- Added the M01-only `runtime/vending_machine_v1` intact visual to the two live `BreakableProp(kind="vending")` placements. The generated product window and weathered casing are fitted to the unchanged gameplay footprint.
- `tools/m01_vending_machine_review.tscn` validates both placements, texture and collision preservation, and the damage transition that hides the intact overlay while restoring the native broken drawing. Windowed evidence: `build/m01_vending_machine_runtime.png`; no navigation, health, sound or collision behavior changed.

### 2026-10-08 — M01 arcade-machine runtime replacement (Codex)
- Added M01-only `runtime/arcade_machine_v1` intact cabinet visuals to both live `BreakableProp(kind="arcade")` placements, with a high-angle CRT/control-panel treatment that reads at gameplay scale.
- `tools/m01_arcade_machine_review.tscn` verifies both overlays, transparent texture content, unchanged PROP-layer collision, and the damage transition back to the established broken cabinet rendering. Windowed evidence: `build/m01_arcade_machine_runtime.png`; navigation, health, sound and collision are unchanged.

### 2026-10-08 — M01 pool-lounger runtime replacement (Codex)
- Added `runtime/pool_lounger_v1` over both visual-only `motel_pool_lounger` anchors. The weathered turquoise/cream lounge chairs carry compact towel and paperback dressing, sized after live pool-patio review.
- `tools/m01_pool_lounger_review.tscn` validates both placements, source texture visibility, hidden former sprites and zero added collision. Windowed evidence: `build/m01_pool_lounger_runtime.png`; no navigation or gameplay behavior changed.

### 2026-10-08 — M01 guest-room clothing-dressing runtime expansion (Codex)
- Extended the existing guest-room accent family with generated `clothes_game.png`: folded windbreaker, denim shirt, T-shirt, belt and room key detail now replace the authored `clothes` dressing entries.
- Both staging and runtime contracts now declare all 13 contained room accents. The existing alpha boundary search keeps every non-transparent pixel within its original guest-room cells and retains no collision or navigation footprint. Runtime evidence: `build/m01_guest_room_accents_runtime.png` and `build/m01_guest_room_accents_runtime_review.json`.

### 2026-10-08 — M01 guest-room towel-dressing runtime expansion (Codex)
- Extended the established guest-room accent family with `towel_game.png`, replacing every authored `towel` dressing entry with a contained ivory/coral motel towel and key-tag treatment.
- Candidate and live runtime review now validate 19 total guest-room accents. Alpha-boundary search retains all opaque pixels within the original guest-room cells; this remains visual-only with no collision or navigation change.

### 2026-10-08 — M01 pool-umbrella runtime replacement (Codex)
- Added `runtime/pool_umbrella_v1` over the live visual-only `motel_pool_umbrella` anchor. The faded coral/cream/turquoise canopy is composed for the pool surface and keeps its original anchor-only behavior.
- `tools/m01_pool_umbrella_review.tscn` validates visible texture, hidden former source sprite, and no child collision. Windowed evidence: `build/m01_pool_umbrella_runtime.png`; navigation and gameplay remain unchanged.

### 2026-10-08 — M01 palm-planter runtime replacement (Codex)
- Added `runtime/palm_planter_v1` over the four visual-only `motel_palm_planter` anchors. The ceramic pot and fan-palm silhouette use the established standing-prop baseline and retain all existing gameplay space.
- `tools/m01_palm_planter_review.tscn` validates all four overlays, texture visibility, hidden former source sprites and zero added collision. Windowed evidence: `build/m01_palm_planter_runtime.png`; navigation and interactions are unchanged.

### 2026-10-08 — M01 vacancy-sign runtime replacement (Codex)
- Added `runtime/vacancy_sign_v1` over the three visual-only `motel_neon_vacancy_sign` anchors. The detailed weathered neon sign retains the existing Decor light fixture rather than adding another emitter.
- `tools/m01_vacancy_sign_review.tscn` validates all three overlays, visible source texture, hidden former sprites and zero added collision. Windowed evidence: `build/m01_vacancy_sign_runtime.png`; navigation and interactions are unchanged.

### 2026-10-08 — M01 exact runtime replacement coverage audit (Codex)
- Added 	ools/art/audit_m01_runtime_replacement_coverage.py, which verifies only exact legacy Decor-family mappings with existing runtime asset, builder, contract where applicable, review evidence, and matching placement counts.
- Current result: 8 exact categories verified, 35 remaining explicitly unverified, 0 audit failures. BreakableProp and room-dressing overlays remain separately evidenced and are deliberately not counted as legacy Decor category coverage.


### 2026-10-08 — M01 pool-flamingo runtime replacement (Codex)
- Added `runtime/pool_flamingo_v1` over the `motel_pool_float_flamingo` anchor. The generated worn float was resized after live review to stay compact at the original water anchor.
- `tools/m01_pool_flamingo_review.tscn` validates its visible texture, hidden former sprite, zero child collision, and preserved animated parent anchor. Windowed evidence: `build/m01_pool_flamingo_runtime.png`; bob/drift, navigation and gameplay remain unchanged.

### 2026-10-08 — M01 live-composition review (Codex)
- Refreshed live Godot captures for courtyard, lounge, reception, office, service, and guest rooms, then assembled uild/m01_runtime_composition_contact_sheet.png.
- Review confirms the current guest-room, pool and exterior replacements read coherently at gameplay scale. Reception/office use the established bright tile lighting pass; it is retained pending an in-motion lighting review rather than being changed from a static capture alone.


### 2026-10-08 — M01 runtime composition luminance audit (Codex)
- Added 	ools/art/audit_m01_runtime_composition.py to validate the six live 800×600 zone captures and guard against global clipped-white lighting.
- Current result: 6 captures, 0 failures. Reception uses 2.842% concentrated clipped-white tile/light pixels, within the 3% capture gate; no global washout was found.


### 2026-10-08 — M01 housekeeping-cart runtime replacement (Codex)
- Added `runtime/housekeeping_cart_v1` over the single visual-only `motel_housekeeping_cart` anchor. Live review corrected the child scale so its inherited anchor transform matches the legacy cart footprint.
- `tools/m01_housekeeping_cart_review.tscn` validates visible texture, hidden former source sprite and zero added collision. Windowed evidence: `build/m01_housekeeping_cart_runtime.png`; navigation and interactions are unchanged.

### 2026-10-08 — Project-wide instrumental music enforcement (Codex)
- User rule: every music track must be instrumental; vocals, spoken content, and gibberish are not allowed in music anywhere in the game.
- `tools/run_godot_review.ps1` now runs `tools/audio/verify_instrumental_audit.py` as a required preflight for all standard Godot reviews. The verifier rejects missing, extra, duplicate, or non-passing entries against the full `music/` library.
- Current verified result: 88/88 music tracks pass with no discernible vocals. Any future non-instrumental music must be replaced with a similar instrumental track before it can pass review.

### 2026-10-08 — M01 pool-ring runtime replacement (Codex)
- Added `runtime/pool_ring_v1` over the live `motel_pool_float` anchor using the authored turquoise/ivory pool-ring source. The overlay is normalized for gameplay scale and retains the parent AnimatedProp bob and drift.
- `tools/m01_pool_ring_review.tscn` verifies the intact visual, hidden former source sprite, zero child collision, and preserved animated anchor. Windowed evidence: `build/m01_pool_ring_runtime.png`; pool navigation and interactions remain unchanged.

### 2026-10-08 — M01 pool-party-remains runtime replacement (Codex)
- Added `runtime/pool_party_ruin_v1` over the live `motel_pool_party_ruin` anchor using the authored abandoned-party source: sun-faded bottles, paper plate, cup and towel are now legible at gameplay scale.
- `tools/m01_pool_party_ruin_review.tscn` verifies its visible texture, hidden former source sprite, zero child collision, and preserved AnimatedProp slow bob/sway. Windowed evidence: `build/m01_pool_party_ruin_runtime.png`; gameplay and pool navigation remain unchanged.

### 2026-10-08 — M01 room-key-spill runtime replacement (Codex)
- Added `runtime/room_key_spill_v1` across all seven `motel_room_key_spill` anchors. The teal/ivory numbered key tags and brass keys provide compact authored storytelling in rooms and pool-side spaces.
- `tools/m01_room_key_spill_review.tscn` verifies every overlay, hidden legacy sprites and zero child collision. Windowed evidence: `build/m01_room_key_spill_runtime.png`; authored transforms, navigation and interactions are unchanged.

### 2026-10-08 — M01 CRT television runtime replacement (Codex)
- Added `runtime/crt_tv_v1` over all three `motel_tv_crt` anchors with a detailed walnut CRT visual at the former footprint.
- `tools/m01_crt_tv_review.tscn` verifies all overlays, hidden former source sprites, retained AmbientScreen pulse scripts and zero child collision. Navigation and interactions are unchanged.

### 2026-10-08 — M01 pool-cooler runtime replacement (Codex)
- Added `runtime/pool_cooler_v1` over both `hq_pool_cooler` anchors using the authored pool-patio cooler source.
- `tools/m01_pool_cooler_review.tscn` verifies two visible overlays, hidden former sprites and zero child collision. Navigation and interactions are unchanged.

### 2026-10-08 — M01 bougainvillea runtime replacement (Codex)
- Added untime/bougainvillea_v1 across three motel_bougainvillea anchors. Focused review verifies visible overlays, hidden source sprites and zero child collision; gameplay navigation is unchanged.

