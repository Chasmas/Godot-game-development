# HOTSHOT CALIFORNIA — Cloud session handoff (2026-10-13)

Paste this whole file as the first message of a new Claude Code session, or attach it and say "continue from this handoff".

---

## 0. Before starting the session (user checklist)

In the environment settings (title-bar chip **"Default · …"** → Edit):

- **Environment variables:** `OPENAI_API_KEY`, `MESHY_API_KEY`, `ELEVENLABS_API_KEY`, `UTHANA_API_KEY` ✅ (already added)
- **Network access → Allowed domains**, with "allow package managers" ticked:
  - `api.openai.com` ✅
  - `api.meshy.ai`
  - `assets.meshy.ai`
  - `api.elevenlabs.io`
  - `api.uthana.com`
  - `lfs.github.com` ← **needed to push images/.blend files** (was blocked last session)
- Repository: `Chasmas/godot-game-development`

---

## 1. Where the work is

| What | Where |
|---|---|
| Repo | `Chasmas/godot-game-development` |
| Branch to work on | `claude/pc-handoff-continuation` (push here every round) |
| PC checkpoint (do not modify) | `codex/pc-handoff-2026-10-12` @ `c20de4d0` |
| Authoritative project doc | `migration/RESUME_HANDOFF.md`: read the **"Cloud continuation"** section at the top first, then the rest |
| Design reference | `docs/design/indie_masterpiece_blueprint_reference.txt` |
| Environment rebuild policy | `assets/art/reference/environment_rebuild_policy.json` |

`RESUME_HANDOFF.md` wins over any older HANDOFF file if they conflict.

---

## 2. Hard rules (from the user and the handoff)

- **Trailer is paused. Do NOT export an EXE.**
- **Preserve the existing Cass model and all existing NPC models.** Locomotion fixes only, with no geometry, face, clothing, proportion or material rebuilds.
- Do not use `git reset`, `git clean` or broad asset deletion. Preserve existing work.
- Keep M01 gameplay geometry, coordinates, doors, windows, breach sequencing and player movement unchanged unless a visual task proves a gameplay defect.
- **Never approve visuals from headless checks alone.** A windowed runtime capture must be inspected first.
- Never commit API keys or the migration `.key`/credential bundle. Never ask the user to paste keys in chat.
- Commit and push verified progress each round to `claude/pc-handoff-continuation`.

---

## 3. Cloud setup that works

```bash
# Godot 4.7.2 Linux (project requires 4.7; the Windows build crashes under wine; NEVER open with Godot 4.4)
curl -L -o /tmp/g.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -o /tmp/g.zip -d /tmp/godot47 && G=/tmp/godot47/Godot_v4.7.2-stable_linux.x86_64

# Blender as a Python module (headless, CPU Cycles only, no GPU)
python3 -m venv /tmp/bpyenv && /tmp/bpyenv/bin/pip install bpy

# Git LFS: full repo is ~25.6 GB, so pull runtime only (~1.6 GB)
git lfs install
git lfs pull --exclude="assets/art/Artwork/**,build/**,migration/**,assets/art/prerendered/**/staging/**"
# Plus the staging folders runtime code actually loads:
git lfs pull --include="assets/art/prerendered/m01_sunset_palms/staging/armored_breach_door_v1/**,assets/art/prerendered/m01_sunset_palms/staging/guest_curtain_v1/**,assets/art/prerendered/m01_sunset_palms/staging/guest_room_props_v1/**"
# Find any others with:
grep -rhoE "res://[^\"']*/staging/[^\"']*" scripts levels data | sort -u

# Import (takes ~30-40 min the first time)
$G --headless --import --path .
```

**Gotchas we hit:**
- Files whose LFS content wasn't downloaded get imported as `valid=false`, which modifies their `.import` files. Restore them with `git checkout -- <file>` and **never commit them**.
- `scripts/levels/level.gd` (and `RESUME_HANDOFF.md`) use **CRLF** line endings. `sed` without `\r` silently does nothing; edit with byte-safe tools.
- A failing GDScript `assert` hangs headless Godot, so always wrap runs in `timeout`.
- Windowed captures: `xvfb-run -a $G --rendering-driver opengl3 --path . res://tools/<review>.tscn` (llvmpipe, CPU).
- If `lfs.github.com` is still blocked, `git push --no-verify` works only for commits **without new LFS files**.
- `pkill -f <pattern>` can kill your own shell; kill by PID instead.

---

## 4. Step 1 of the new session: verify the APIs

One cheap call each, and report what works:
- OpenAI: `GET https://api.openai.com/v1/models` (Bearer `$OPENAI_API_KEY`), then one small image generation for ImageGen references.
- Meshy: `GET https://api.meshy.ai/openapi/v1/balance` or similar (Bearer `$MESHY_API_KEY`).
- ElevenLabs: `GET https://api.elevenlabs.io/v1/user` (`xi-api-key: $ELEVENLABS_API_KEY`).
- Uthana: a light authenticated call to `api.uthana.com`.

The repo already contains integration scripts for these (Meshy/ElevenLabs/Uthana pipelines under `tools/`). Reuse them instead of rewriting.

---

## 5. Unfinished item from last session: guest clutter batch

**Status: built, hooked in, NOT approved, live review not yet passed.**

- Replaces the exact legacy Decor families `clutter_ashtray` (6 placements) and `clutter_bottles` (6) in M01, visual-only (no collision or navigation change).
- Builder: `tools/art/build_m01_guest_clutter.py`. Blender geometry directed by `assets/art/materials/m01/batch_v1/ashtray_reference.png`, `bottle_weapon_reference.png` and the approved guest-room reference `guest_room_rebuild_direction_v2.png`.
- Output: `assets/art/prerendered/m01_sunset_palms/runtime/guest_clutter_v1/` (contract committed with `runtime_approved:false`, widths 9 px / 10 px).
  - **The PNG and .blend files were NOT pushed** (LFS upload was blocked). Regenerate with `/tmp/bpyenv/bin/python tools/art/build_m01_guest_clutter.py` (~5 s), then re-import.
- Runtime: `scripts/levels/m01_native_guest_clutter.gd`, called in `Level` right after `M01NativeGuestIceBuckets.build(self)`. Inert until approved.
- Review: `tools/m01_guest_clutter_review.tscn` (asserts 12 placements, no collisions, exact widths, records legacy widths; saves `build/m01_guest_clutter_runtime_N.png` when windowed).

**To finish it:**
1. Regenerate the renders, then import.
2. Run `tools/m01_current_composition_review.tscn` headless. It failed last time only because the armored breach staging PNGs were LFS pointers.
3. Run the clutter review headless, then windowed under xvfb. Inspect all 12 captures and compare with `legacy_width_px` in `build/m01_guest_clutter_review.json`. Adjust widths or art if needed.
4. If it looks right, set `runtime_approved: true` plus a `visual_review` note in the contract. Add inventory evidence rows (`m01_guest_ashtray`, `m01_guest_bottles`) to `build/m01_asset_replacement_inventory.json`, and add `DIRECT` entries in `tools/art/audit_m01_runtime_replacement_coverage.py`. Run the audit (expect 20 verified / 23 remaining).
5. Append a dated checkpoint to `RESUME_HANDOFF.md`, then commit and push.

Reference pattern for all of this: the ice-bucket batch (`build_m01_guest_ice_buckets.py`, `m01_native_guest_ice_buckets.gd`, `m01_guest_ice_buckets_review.gd`).

---

## 6. Priorities after that (from RESUME_HANDOFF)

1. **M01 guest-room/environment rebuild.** Replace the remaining procedural visual-only props via ImageGen reference (in `staging/`), then Blender source/render plus `contract.json` (in `runtime/`), then a narrowly scoped native `Sprite2D`, then a live windowed map review. Collision, navigation and anchors stay authoritative. The 23 remaining unverified Decor categories are: arcade, dumpster, hq_motel_dresser, hq_motel_ice_machine, hq_motel_vending, hq_palm_planter, hq_pool_lounger_set, lamp, laundry_service_bench, motel_gecko, motel_hasty_checkout, motel_ice_machine, motel_water_ring, neon, palm, paper, road_* (arrow, manhole, patch, pothole, sand, stop_line), vacancy. Per user policy, prefer **recomposing rooms** over one-for-one swaps, and audit before claiming coverage.
2. **Cass and all-NPC locomotion** (walk/run/sneak, strafe/back/turn/stop, no foot sliding, every cast including civilians, bosses and dogs) on the existing models.
3. Open weapon issues: NPC katana grip, and an extra blade in Cass's other hand during katana attacks.
4. **After locomotion:** the intro becomes a real animated video with character and camera motion (Blender/ImageGen/etc.), preserving the story. This is separate from the paused trailer.
5. Long-term scope (do not shrink): 16 levels with unique music, bosses with epic intros, varied enemies, a full premium visual polish pass.

---

## 7. Ready-to-paste start command

```
/loop Continue HOTSHOT CALIFORNIA in Chasmas/godot-game-development using the attached cloud handoff. Check out branch claude/pc-handoff-continuation, read the "Cloud continuation" section at the top of migration/RESUME_HANDOFF.md and then the rest (authoritative). Set up exactly as the handoff says. First verify the four API keys with one cheap call each and report. Then finish the guest clutter batch (regenerate renders, composition + clutter reviews, windowed inspection, approve only if right), and continue the M01 rebuild per the handoff. Preserve Cass/NPC models; trailer paused; no EXE. Commit and push verified progress to claude/pc-handoff-continuation each round.
```
