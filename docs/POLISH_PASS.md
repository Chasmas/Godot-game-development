# Polish pass: development summary

This covers every phase of the overhaul brief. Each claim below links to something measurable: a test, a number or a screenshot. Where something wasn't done or couldn't be verified, it says so.

## 1. What was causing the "random crashes"

I never saw a hard engine crash here (I had no crash log from your machine). Three problems that grow with enemy count would each make the game freeze or hitch badly enough to look like a crash, and I fixed all three:

1. **Cost that grew with the square of enemy count, multiplied by the physics settings.**
   - Every enemy scanned every other enemy for spacing on every 120 Hz tick, and allocated a fresh array each time.
   - Every door scanned every enemy and the player on every tick.
   - Physics ran at 120 Hz with up to **12 catch-up steps per frame**. Once one frame overran, the next ran up to 12 ticks, which overran worse. That spiral locks the game up, and Windows reports it as "not responding".
2. **Paint stalls.** Character textures are painted pixel by pixel in GDScript the first time each look or pose appears, such as the first punch or the first knockdown. With per-enemy variants in a big fight, these stacked into 17–20 ms ticks.
3. **Logic races that break state:**
   - `Enemy._die()` could run twice. That happened when an execution finished on an enemy killed the same frame, and it produced a double corpse, double score and a double `died` signal.
   - `Game.change_scene()` silently dropped any request made during a fade. A mission starting while a cutscene ended would never load.
   - Kicks swung doors *back through* the player because of a reversed sign.

If crashes still happen on your PC, Godot writes a log to `%APPDATA%\Godot\app_userdata\HOTSHOT CALIFORNIA\logs\godot.log`. That file will show what's crashing.

### Numbers (`tools/stress_test.tscn`)

Physics cost per 120 Hz tick, measured headless on this server's CPU:

| enemies in combat | before, average | before, worst | after, average | after, worst |
|---|---|---|---|---|
| 10 | 0.87 ms | 3.7 ms | 0.84 ms | 4.1 ms |
| 30 | 1.90 ms | 4.7 ms | 1.51 ms | 3.0 ms |
| 50 | 3.37 ms | 8.0 ms | 2.48 ms | 5.5 ms |
| 80 | 6.22 ms | 12.7 ms | 3.40 ms | 6.9 ms |

- Spacing went from 2.93 ms per tick at 80 enemies to about 0.4 ms, so total cost now grows roughly in line with enemy count.
- Catch-up physics steps are capped at 5. An overloaded frame now slows the game for a moment instead of spiralling.
- The budget per tick is 8.3 ms. The stress test puts 80 enemies in one fight; the missions have 17–26 enemies spread over the whole map.

## Fixed
- The game freezes and hitches in large fights described above: quadratic spacing and door scans, the 12-step catch-up spiral, and first-appearance paint stalls.
- `Enemy._die()` running twice for one enemy.
- Scene changes lost during fades.
- Door kicks and melee hits swinging the door toward the attacker.
- Doors creeping forever: they now come to rest, and they stop against walls instead of clipping.
- A guard's own door-opening noise dragging the rest of its group off their investigation.
- Speech bubbles clipping through walls and props and running off screen: they now render in screen space.
- The Subtitles setting was saved but never used. It now hides world chatter.
- Reloads applying to the wrong gun: swapping or throwing mid-reload now cancels the reload.

## Improved
- **Hearing (`Hearing`)**:
  - A sound's reach shrinks with distance and with every wall and closed door in the way.
  - There's a chance-based falloff near the edge of hearing.
  - Listeners get an *estimate* of where the sound came from, never the player's exact position.
  - Weapon noise was rebalanced: suppressed pistol < pistol < SMG < rifle < shotgun < explosions.
- **Alerts:**
  - A guard who spots you shouts once per cooldown.
  - Allies go to the shouter's area and look for themselves.
  - Three pistol shots outside wake 1 of 25 enemies; one shout alerts 0 of 16 enemies more than 400 px away.
- **Search:**
  - Investigators pick their own spots near the report, so groups don't stack.
  - Searches visit several points and look around at each.
  - Afterwards enemies calm down and walk back to their posts (new RETURN state).
- **Crowds:**
  - Enemies no longer collide with each other physically. Spacing comes from steering on a shared spatial hash, with smoothed acceleration.
  - Two guards pass the same doorway in about a second, never less than 13 px apart.
  - Attack tokens limit how many enemies shoot at you or rush you at once. The rest take positions around you, and flankers swing wide.
- **Doors:**
  - Motion is now a damped hinge: an impulse, then friction and drag.
  - A kick throws splinters and dust, with hit-stop, a camera nudge, controller rumble and a new synthesized sound.
  - A kicked door flattens whoever is behind it.
  - You can't kick through walls or while facing away from the door.
- **Dodge:** 46 px instead of 64.5 px. It starts fast and eases out, and ends cleanly when it hits a wall.
- **Enemy readability:** calm guards carry guns low, wary ones half-raised, alerted ones up. Alert icons pop in.
- **Weapons:**
  - Muzzle flash size varies per weapon.
  - Shells fly out of the ejection port and bounce once with a tinkle (revolvers keep their brass).
  - The shotgun and revolver shove the camera and freeze for a hair.
  - Bullets hitting walls kick up dust.
  - The crosshair opens on each shot, shows a white X on hits and a red X on kills, and has a reload ring.
- **AI update cost:**
  - Calm, distant enemies look around less often, on staggered timers.
  - Combat reuses line-of-sight results from the perception tick.
  - Difficulty values are cached.

## Added
- **Difficulty** (Easy / Normal / Hard): picked on New Game and changeable in OPTIONS. All values are in `Tuning`.
  - Easy: slower enemy reactions, worse aim, and one regenerating guard hit for the player.
  - Hard: faster reactions, better aim and hearing, more simultaneous attackers, more flanking and less ammo.
- **Dual wielding** for pistols (including the Whisper) and SMGs:
  - The guns alternate, each with its own magazine, from its own muzzle, with its own recoil.
  - Combined fire rate is 1.6×, with 1.35× spread, 1.3× bloom and a 1.5× reload.
  - Throwing tosses the off-hand gun, and checkpoints keep the pair.
- **Portuguese** (see below).
- **Room set dressing** and **wall detail** (see below).
- **Area ambience** and a **distant-sound filter** (see below).
- **Central tuning** (`scripts/systems/tuning.gd`, overridable from `data/tuning.tres`).
- **Dev tools:**
  - stress test, edge-case suite and one-shot `tools/run_tests.sh`
  - translation extractor and coverage check
  - character sheet
  - sprite baker
  - a close-up screenshot mode
- **Accessibility:** subtitle size, text speed, set-dressing toggle, and the Subtitles setting now does something.

## Characters and animation
- **Silhouette-first redesigns**, since a character is about 16 px on screen:
  - guard: peaked cap, badge, epaulettes and radio antenna
  - gunner: padded 80s shoulders
  - hunter: sleeveless, with dog tags
  - heavy: thicker neck and stubble
  - scout: Walkman headphones and mullet
  - boss: lapels and a pocket square
- **Cass**, as the lead, got the most detail: a popped collar, aviators pushed up into her hair, and a sheen on her jacket that reads in dark rooms.
- **Per-enemy variants:** skin tone, hair and trouser shade differ between guards. The look stays stable per enemy and carries over to downed poses and corpses.
- **Mannerisms:** per-type sway, lean and bounce while walking, a kick pose, and weapon posture.
- **Portraits** get per-character temperaments:
  - Cass: calm, with slow blinks.
  - Earl: nervous, blinks fast, eyes darting, sweating.
  - The anchor: eyes fixed on the camera.
  - Harcourt: theatrical, with one eyebrow up.
  - The guard: bored, with heavy lids.
  - Moods (angry, shock, sad, scared, smirk, smile) ease in and can be set per dialogue line or inferred from punctuation.
- **German Shepherd:**
  - Look: a black saddle and muzzle mask, big upright ears, a deep chest and a bushy black-tipped tail.
  - Movement: the head tracks what the dog is watching. It trots or gallops, turns and stops smoothly, pants after running, twitches its ears, and raises its hackles when alert.
  - Detection: once it spots you, its eyes burn red with a halo and a small red light, flaring at the moment of detection.

## World
- **Room-aware set dressing** (`scripts/levels/dressing.gd`):
  - Rooms are found by flood fill and classified from their floor and furniture: guest room, corridor, lobby, laundry, office, lounge, industrial, kennel, courtyard, lot or yard.
  - Each type has its own props: suitcases and room-service trays in guest rooms, papers and coffee rings in offices, oil drums and stains in industrial rooms, bowls and hay in kennels.
  - Doorways, spawn points and pickups stay clear.
  - No collision or navigation changes, and each layer is drawn once.
- **Wall faces:**
  - room numbers beside guest-room doors
  - pictures and AC units in rooms
  - extinguishers and notices in corridors
  - a key rack in the lobby
  - pipes and gauges in industrial rooms
  - BEWARE signs in kennels
  - EXIT signs over doors to outside
- **Light:** warm pools of light under bedside lamps (no extra dynamic lights), and dust motes in lit interiors.
- **Not changed:** the floors already had procedural materials and contact shading, so I left them alone. No level layouts or story beats were changed.

## UI
- **Options menu:**
  - Rebuilds in place when the language changes.
  - Has language and difficulty pickers, and a help line for the focused setting.
  - Labels wrap instead of clipping, and the menu slides in and out.
- **Menus:** focus feedback on buttons, staggered menu reveals, and title-screen panels that drop in.
- **Pause:** slides in over a fading backdrop, with a side panel showing the mission, objective and difficulty.
- **Dialogue box:** grows to fit long lines at any text size.
- **Speech bubbles:**
  - rendered in screen space, with wrapping
  - kept clear of the HUD
  - stacked so they don't overlap
  - pinned to the screen edge for off-screen speakers

## Localization
- **How it works:**
  - English text is the key, and each language is one JSON file (`data/i18n/pt_PT.json`).
  - The `Loc` autoload loads it into Godot's translation system, applies the saved language at boot, and switches live.
  - Built-up strings go through `tr()`, and anything missing falls back to English.
- **Coverage:** 581 of 581 player-facing strings are translated, checked by `tools/i18n_extract.py --check pt_PT` inside `run_tests.sh`. That includes menus, options, HUD, prompts, hints, objectives, all dialogue and speaker names, characters, personas, weapons, enemies, missions, upgrades and executions.
- **Which Portuguese:** European Portuguese (pt-PT). I chose it because your earlier session's timezone was Europe/Lisbon. Adding pt-BR later means adding one more file.
- **Kept in English:** signs painted into the world (POOL, EXIT, BEWARE OF DOG, business names) stay English on purpose, as they would in 1988 California. Proper names and brand-style weapon names are unchanged.
- **Tested:**
  - switching language mid-conversation
  - the longest Portuguese text fitting at the largest size
  - speech bubbles at the screen corners and off screen
  - the language being saved to `settings.json`
  - the HUD in Portuguese

## Audio
- **Distant sounds:** sounds more than about 340 px from the view centre go through a low-passed, slightly reverberant bus, so distance changes the sound, not just the volume.
- **Area ambience:** motel interior hum, night exterior with wind and crickets, industrial machinery and kennel.
  - The beds are seamless loops that crossfade by area and start at random offsets.
  - Occasional distant one-shots (a car passing, a far bark) cover the loop.
- **New sounds:** a door kick, a passing car and four ambience beds. All were synthesized and appended to `tools/gen_audio.py`; every existing sound file is byte-identical.

## Testing
Everything below passes on the final commit (`tools/run_tests.sh`):
- **Smoke test:** a full automated playthrough of both missions, including the boss, the dialogue choice, death and restart, and save/load.
- **Edge-case suite:** 17 cases with 49 checks, covering:
  - hearing and wall muffling
  - kills mid-investigation, rapid fire, and spawning while shooting
  - a door kicked into an enemy, and doorway traffic
  - dodging into walls
  - the double-death race
  - shouts staying local, and difficulty scaling
  - dual wielding (including swapping mid-reload)
  - five localization cases
- **Stress test:** 5 to 80 enemies, then mass death. No failures, no orphaned nodes.
- **Translation coverage:** 581/581.
- **Visual review** of Mission 1 rooms, the dog, the character sheet, and the Portuguese menus and HUD, rendered under Xvfb with software OpenGL.

## Remaining issues and limits
- **The crash itself.** I fixed every cause I could find and measure, but never saw a hard crash here. If one still happens on your PC, the Godot log path in section 1 will show what it is.
- **Not tested on your hardware.**
  - All runs were Linux: headless, plus Xvfb with software OpenGL.
  - Rendering and GPU cost weren't profiled.
  - The Windows build wasn't tested.
  - No physical controller was used.
- **Feel wasn't hand-tested.** Dodge distance, kick force, door physics and dual-wield balance were set from measurements and reasoning, not by me playing with a controller. Tune them in `Tuning` after playing.
- **3D items in the brief don't apply.** Normal maps, roughness and metallic maps, PBR materials, LODs and polygon counts have no meaning in this 2D pixel-art game. I did the 2D equivalents instead: silhouettes, cel-shaded detail, set dressing and light pools.
- **Aim sensitivity wasn't added.** Stick aiming here sets a direction rather than moving a cursor, so a sensitivity slider wouldn't do anything. Aim assist remains.
- **The Portuguese needs a native read.** I wrote it; a native speaker should proofread the dialogue's tone.
- **Levels weren't redesigned.** Environment detail is automatic set dressing on the existing maps; no rooms, layouts or bespoke art were added.
- **Most dialogue lines don't set moods yet.** Portraits infer a mood from punctuation, but explicit `"mood"` tags have to be added line by line in `data/dialogue/*.json`.
