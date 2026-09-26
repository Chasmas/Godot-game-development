# HOTSHOT CALIFORNIA — vertical slice

A fast, violent, surreal top-down action game set in California, 1988–1992.
Built in **Godot 4.4** (GL Compatibility renderer), all GDScript.

## Run it
1. Open Godot 4.4+ → **Import** → pick `project.godot` in this folder.
2. Press **F5** (the main scene is `scenes/boot.tscn` → title screen).

First launch imports the audio/fonts (a few seconds).

## What's in the slice
- **Title screen**: animated freeway/neon/rain backdrop, VHS OSD, chrome-sunset logo. Menus: continue, new game, chapters, arcade + challenges with a local leaderboard, cast, extras (evidence locker, stats, credits), options.
- **Story**: prologue (the 1987 stunt), the answering-machine scene (with a choice), **Mission 1 "Checkout Time"** at the Sunset Palms Motel, a TV news epilogue that reacts to what you did, and a teaser for 1990–1992.
- **Mission 1**: a big motel level. Parking lot, laundry, a corridor of rooms, a lounge, a pool courtyard, an upstairs wing, a boiler room, the office and the lobby. There are several ways in (service door, dive through a room window, the alley gate). It has a secret room, 2 evidence collectibles, 2 NPCs, 24 enemies and a boss.
- **Boss: Lyle Harcourt, the Night Manager.** In phase 1 he fights from cover; every hit to his armour sends him to new cover and brings security in over the intercom. In phase 2 he cuts the power: it goes pitch black, he hunts you with a shotgun, and his flashlight is the only light. At the end you choose to execute him or walk away, and later scenes react to that choice.
- **Combat**: one-hit deaths both ways. There are 7 firearms (recoil, bloom, spread, penetration, ricochet, magazines and reloads), 6 melee weapons (quick, heavy and counter attacks; bottles break into shivs) and punches. You can throw anything (bladed weapons kill, everything else knocks people down), knock enemies down and execute them, and dash (with i-frames) to vault tables, dive through windows or tackle.
- **Doors** open as you walk through, kicks and dashes slam them into people, and they can be shot apart. Windows shatter. Propane tanks chain-explode. Fuse boxes kill a zone's lights. Lamps can be shot out. The alarm panel can be smashed before a scout reaches it.
- **Enemy AI** (IDLE, PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, COMBAT, FLANK, RETREAT, CALL_REINFORCEMENTS, PANIC, FLEE, DOWNED, STUNNED). Enemies use a vision cone with line of sight that shrinks in the dark, react to noises through walls, find bodies, pass alerts on, and path on an A* grid.
  - **Guard**: patrols, reacts after a fair delay, and shoots.
  - **Gunner**: fires in bursts.
  - **Hunter**: fast melee rusher with a telegraphed, counterable swing.
  - **Heavy**: his vest stops one bullet, and fists and doors don't work on him.
  - **Scout**: unarmed, runs for the alarm.
  - **Riot**: his front shield blocks you, so flank him or stagger him with a door or a thrown weapon.
- **Score and combo**: chain kills inside the combo window. Variety, silent kills, momentum and method bonuses stack. Ranks go C → B → A → A+ → S → S+ → SS → SSS. There's a local top-10 leaderboard per mission.
- **Signature ability**: Cass's *SPOTLIGHT* slows the world while you keep near-normal speed. It charges through play. **Equipment**: road flares that light a room and pull enemies toward them.
- **Instant restart** from the last checkpoint. Dead enemies stay dead and your loadout is kept.
- **Dynamic music**: 4 stems (explore, combat, combo, danger) crossfade with the action. There's a separate boss track with a "lights out" layer, plus title, apartment and aftermath tracks. All music and ~50 SFX were synthesized from code (`tools/gen_audio.py`).
- **Settings**: master, music, SFX and dialogue volume, fullscreen, VSync, window size, CRT, chromatic aberration, brightness, FPS counter, screen shake, gore (off, reduced, full), aim assist, vibration, subtitles, colour-blind filters, reduced flashing, UI scale, and full keyboard, mouse and gamepad remapping.
- **Save system**: separate JSON files for settings and progress. Writes are atomic (temp file, then backup, then rename), and loading falls back to the backup if the main file is corrupt.
- **Debug menu (F1)** in editor/debug builds: god mode, spawn weapon/enemy, teleport, kill all, AI inspector (state + vision cone + path), FPS, collision shapes, unlock all.

## Controls
| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Aim | Mouse | Right stick (optional aim assist) |
| Fire / attack (hold to charge heavy melee) | LMB | RT |
| Throw weapon | RMB | LT |
| Dash / dodge / vault / dive | Space | A |
| Sprint (standing still: peek further) | Shift | L3 |
| Interact / pick up / talk | E | X |
| Quick swap (2 slots) | Q | Y |
| Reload | R | R3 |
| Execute downed enemy / kick door | F | B |
| Ability (SPOTLIGHT) | C / MMB | RB |
| Equipment (flare) | G | LB |
| Objectives | Tab (hold) | Back |
| Pause | Esc | Start |
| Restart after death | R / LMB | A |

## Project layout
```
scenes/            boot, title, level, cutscene, results (thin .tscn, logic in scripts)
scripts/player/    Player, CharacterVisual, CameraController, AbilitySystem, CharacterData
scripts/enemies/   Enemy (state machine), BossNightManager, NPC, Corpse, EnemyData
scripts/weapons/   WeaponData, WeaponInstance, WeaponPickup, BulletSystem, Flare
scripts/levels/    Level, LevelBuilder, Door, GlassWindow, BreakableProp, ExplosiveTank,
                   AlarmPanel, Furniture, LightFixture, Interactable, MissionData
scripts/systems/   autoloads (Events bus, Game, SaveManager, InputSetup, Audio, Music,
                   Score, PostFX, DebugMenu), DB registry, SpriteLib, Effects, DamageInfo, Layers
scripts/narrative/ Dialogue manager, portraits, cutscene
scripts/ui/        HUD, pause, options, title, results, UIStyle
data/              .tres resources: weapons, enemies, characters, personas, missions;
                   JSON: dialogue, campaign order, music stems
levels/            level files (ASCII map + JSON metadata)
shaders/           VHS/CRT post-process, logo gradient
music/, assets/    generated audio, fonts
tools/             gen_audio.py, gen_data.py, build_m01.py (level authoring),
                   smoke_test.tscn (automated playthrough), screenshot tool
```

## Adding content
- **Weapon**: add an entry in `tools/gen_data.py` (or duplicate a `.tres` in `data/weapons`). It's picked up automatically.
- **Enemy archetype**: add a `data/enemies/*.tres`. Behaviour comes from `combat`, perception and tuning fields.
- **Level**: write a map with the legend in `tools/build_m01.py`, then add a `MissionData` pointing at it and an entry in `data/missions/campaign.json`.
- **Dialogue**: add `data/dialogue/<id>.json`. It supports speakers, choices, flags, conditions, branches, SFX and script events.
- **Art/audio**: sprites are ASCII in `SpriteLib`. Register a PNG in `SpriteLib.OVERRIDES` to replace one. To replace any `.wav` or `.ogg`, drop in a file with the same name.

## Testing
```
godot --headless --path . res://tools/smoke_test.tscn
```
This compiles every script, then plays Mission 1 automatically: movement, dash, punch and execute, shooting, throwing, pickups, melee, door kicks, glass, explosions, AI hearing, death and instant restart, checkpoints, the boss's two phases, the dialogue choice, the phone call, the escape, the results screen, and a save/load round trip.

## Not in this slice yet
The other nine playable characters are designed (see the CAST menu and `docs/STORY.md`) but not yet playable. The same goes for the abilities other than SPOTLIGHT (stubbed in `AbilitySystem`), chapters 2–4, New Game+, Remix and Nightmare modes, vehicles, and body dragging.
