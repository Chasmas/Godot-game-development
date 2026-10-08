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
