# Resume checkpoint — 2026-10-08, Europe/Lisbon

This file supersedes historical HANDOFF*.md where they conflict. Preserve all earlier work; do not reset or clean the checkout.

## Immediate work
The user approved ImageGen `assets/art/materials/m01/batch_v1/guest_room_rebuild_direction_v2.png` as guest-room visual direction. Exact prompt is beside it. This is **reference art**, not reconstructed runtime quality.
Blender builder: `tools/art/build_m01_guest_room_composition.py`, latest `staging/guest_room_composition_v4/guest_room_composition.blend` and PNG under `assets/art/prerendered/m01_sunset_palms/`. Window, curtains and blinds now assembled; chair faces TV. Latest render is sparse and chair corner too dark. Improve toward approved ImageGen reference: textile folds, meaningful belongings, botanical artwork, materials, lamps, window dressing, wear. Do not promote this prototype as final.
Camera comparison: `tools/art/review_m01_room_camera_angles.py`, renders in `staging/guest_room_camera_review_v1`. 30-degree yaw shows more volume, but no gameplay projection integration yet. User authorizes layout/camera changes only while preserving gameplay. Must align floor, actors, aim, collision, input and occlusion.

User now explicitly prefers **removing obsolete decor and recomposing environments from scratch**, not one-for-one replacement at arbitrary old positions. Applies to all future environments. Policy: `assets/art/reference/environment_rebuild_policy.json`. Preserve/rebuild functional gameplay entities (doors, switches, pickups, objectives, checkpoints). Quality minimum: approved pool reference, detailed angel and supplied environment references. Audit coverage before claiming all assets ready. `build/m01_asset_replacement_inventory.json`: 43 authored decor categories, 146 ImageGen images, 19 Blender scenes at inventory time; counts alone do not prove coverage.

## Production vs staging
- M01 ten beds integrated by `M01NativeBeds`, shared texture, isotropic scale, original bodies/colliders. Bed RGB brightness .65. Ground source hash revalidated after removal of two invalid decorative beds. `tools/m01_native_beds_runtime_review.tscn` passes ground-active, beds and actual player sweeps.
- M01 native armchairs integrated with physical volumes/navigation. Bedside cabinets (21), dressers (7), wall v6 and rug assembled review remain staging. `tools/m01_native_bed_review.tscn` loads review flags only; checks actor overlaps, collision, navigation and chair clearance. GPU captures are under build. Do not infer art quality from checks.
- Wall current-grid alpha audit: `tools/art/audit_m01_wall_projection.py`, 538 visible wall cells, zero pixels outside wall cells. Footprint evidence only.
- Sleeping chairs solid; occupant exception expires after exit; navigation query reserves chair footprints temporarily. Actual Enemy steering four-direction chair test passes `tools/m01_chair_steering_review.tscn`.
- Ten cast doze animations repaired (bellhop, biker, cass, gunner, handler, heavy, hunter, security, sniper, stagehand). Source geometry/materials/other clips preserved. Candidate backups and reports under `build/seated_contacts`. Four-facing review inspected, posture/transition tests passed. This does not approve redesigned casts.
- Undead: 24 planned appearance variants in `assets/art/reference/cast_redesign_v1/undead_variant_direction.json`; runtime false. Victims must derive from prior campaign kills; living civilians never become nightmare victims. No zombies/demons smoke.

## Large remaining scope — do not shrink
All cast ImageGen→Blender distinctive models, rigs, anatomy and animation; M01 coherent reference-quality environment then all levels; Villa cemetery/mausoleum/gates/fog/emergence; 8 distinct civilians, 2–3 per normal level; nightmare civilians only if previously killed. Full FMV cutscenes, animated dialogue portraits, context-appropriate human voices (older mom), Cass red coat, expanded story. No vocals or gibberish in any music. Jukebox unique artwork/vinyl, plain music titles and correct music transitions. Full HUD/UI/menu/studio intro coherent art and up to 4K. Knife/punch/execution animations, slower responsive locomotion/roll, no sliding, lock-on release, car exit, leash physics, spotlight. Rare chainsaw guaranteed limb severing, machete high rate, persistent blood on props/walls and brief corpse spurts. Surveillance/enemy layout, discreet tilted spinning neon tape checkpoints. Trailer paused, no EXE/export.
Cass fist candidates remain unapproved; no finger rig, primitive studies inadequate. Doberman new rig/clips remain candidate, missing full bite/death/sprint validation. New Meshy cast models not runtime-approved. Earlier exhaustive evidence in COORDINATION.md (mixed encoding; append bytes, do not assume UTF-8) and historical HANDOFF files.

## New PC
Run migration/START-HERE.cmd. Tool paths are recorded in `.toolchain/paths.json`; old scripts may contain old absolute paths and must be adjusted when encountered. Godot build is transferred exactly in the archive, not fetched as an uncertain newer version. The exact Blender installation is also transferred in an archive; winget is fallback only. Compare its version before rebaking approved assets. Python dependencies in migration/requirements.txt. Existing remote API jobs/results are in source task manifests; re-check live state before paying for duplicate work.
Sign into Codex; image generation uses its built-in tool. Reconnect PixelLab/MCP and any Blender/Godot connectors installed in the previous Codex profile. API credentials import from encrypted bundle using a private .key file copied separately. Never commit that private key or plaintext credentials.
No automatic chat/goal/connector/session transfer is guaranteed. Open this repository in Codex and paste migration/RESUME.txt. All tasks remain incomplete until source and runtime evidence prove them.

The user explicitly authorizes continuing with full project/filesystem/network/API access on the new PC. The user must enable the actual Codex permission profile on that host. Respect its effective runtime permissions; this handoff cannot grant technical permissions.

Use SOL medium only if available in the new host model selector, as requested by the user. No model selector is available in this current tool interface.

Godot AI MCP is configured by setup using pinned godot-ai 4.2.3 and the transferred addons/godot_ai project addon, ports 8001/8002. Existing Codex server config is preserved. Built-in node_repl is supplied by Codex, not migrated from this machine.

Before rendering an unpacked Blender source on the new PC, use migration/relink_blender_sources.py via Blender --background --python ... -- <source.blend>. It maps only known old project-root image paths, makes them relative, and refuses to save if any image remains unresolved. It does not guess ambiguous image matches or replace textures.

Original user-supplied environment quality references (including pool and angel screenshots) are preserved in migration/reference-images; use them as references, not commercial shipping textures. Eleven explicit originals copied successfully.
