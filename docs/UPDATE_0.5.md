# HOTSHOT CALIFORNIA 0.5.0

## Presentation
- **Intro:** a cold open between the studio splash and the title. A tape starts, the story flashes past in illustrated shots with typed captions, and the logo slams in.
- **Title:** any key, click, pad button or stick starts it. The version text is gone.
- **Story cutscenes:** 19 painted, layered shots (`tools/art/`) with camera moves, parallax and per-layer animation. The animation covers LEDs, police lights, the clapper, dog eyes and firelight. Effects add rain, embers, smoke and static, with letterbox bars and glitch cuts.
- **Portraits:** painted to match, with rest, talk and blink frames. Cass wears the gold star after she paints it on.
- **Chapter select:** a shelf of VHS tapes with cover art. Locked tapes show tracking noise and a DAMAGED sticker.
- **Speech:** babble voices and animated letters in dialogue and speech bubbles. The letters shake, tremble or waver with the line's mood.
- **Upgrades:** drawn icons, briefcase holograms, HUD badges and an animated pickup card.
- **Tutorial:** DIRECTOR'S NOTE tips appear once, in context. They can be turned off in Options > Access.
- **Lock-on:** a marker over the locked target.
- **Results screen:** THE VOICE's director's notes review your take.

## Game feel
- **Guns:** jagged two-frame muzzle flashes, sparks, gun smoke, a little barrel flip and a small camera punch per shot.
- **Reloads:** animated. The empty mag drops out, a fresh one slaps in and the slide is racked. Shotguns load shell by shell.
- **Melee:** anticipation, an expo-eased strike with body stretch, overshoot, weapon afterimages and a whoosh.
- **Idle life:** guards and civilians smoke, drink, eat or doze. Dozers sleep through footsteps but not through gunfire.
- **Enemy aim:** enemies roll a hit chance, and misses crack past as near misses.

## Rhythm
- **Beat kills:** kills that land on the music's beat score extra, and several in a row build a RHYTHM streak.
- **HUD:** a metronome under the combo, with HOT, ON FIRE and SHOWSTOPPER tier callouts.
- **FINAL TAKE:** a melee kill at combo 8+ triggers a slow-motion REC finisher.
- **Music:** new rhythm-first four-stem scores: *Checkout Time* for the motel and *Dog Days* for the yard. Alerted enemies who spot you still push the intensity up.

## Level content
- **New enemies:** the Sniper (laser tell) and the Dog Handler (lets the dog go when he spots you). Each level also has its own roster:
  - Motel: the Bellhop and the Biker.
  - Salvage yard: the Scrapper and the Welder.
- **Security cameras:** a sweeping, wall-clipped cone and a spot meter. Getting spotted raises the alarm and sends the three nearest guards. Shooting a camera out makes one or two guards come and look.
- **Hidden cameras:** THE VOICE's own cameras. Kills they see score FOR THE CAMERA, or you can CUT THE FEED.
- **Checkpoints:** each has a floor marker at the area's entrance. They save only when it's fair, and a TAPE SAVED stamp confirms it.
- **Smashables:** vases, boxes, crates, chairs and drums break, and some drop loot.
- **Glass:** it shatters into real shards and leaves a Glass Shard weapon.

## Stability
- **Crash fixes:**
  - A crash under heavy combat, caused by a slow-motion timer outliving its level.
  - Prop spawns during teardown.
  - The positional audio pool changing bus on a live player.
- **Tests:** the smoke, edge and stress suites (up to 80 enemies) pass, with 642/642 Portuguese strings.

## 0.5.0 — feedback pass: synthwave, 80s cutscenes, fairer stealth

- **Music**: both level scores rewritten as proper synthwave: a verse and a chorus,
  side-chained supersaw pads, octave-pulse bass, gated 80s snare, FM e-piano, a big
  detuned lead hook, tom fills and risers. Same beat grid and bpm, same four
  intensity stems (explore / combat / combo / danger), so alerted enemies and combos
  still drive how it plays.
- **Cutscenes**: new 80s poster style with flat cel colour, ink outlines, neon rims and
  synthwave skies. No more hands or arms. Memorable silhouettes: Cass's big red hair,
  aviators and red leather; Tommy's pompadour, denim and cigarette; Marv at a stand mic.
  Tommy now drives facing the road (seen from the passenger seat). The dialogue portraits
  use the same style.
- **Stealth**:
  - Enemies see about 22% less far.
  - An alarm sends at most 3 responders, radio reinforcements included.
  - Security cameras have a dead zone right under the lens: hug the wall to slip
    underneath. The cone is drawn with that gap.
- **Readability**:
  - Dozing guards slump in a folding chair with their feet out, big comic Zs and a
    snore bubble. When startled, the chair tips over.
  - The dog handler's shepherd really walks at heel (trotting legs, head, panting) on
    a leash that sags and pulls taut.
- **Camera**: slightly closer to the player.
- **Dogs** attack less abruptly: slower run (shepherd 190→160, rottweiler 165→145),
  a longer growl before the lunge, a shorter lunge and more recovery between bites.
- **Dog handler** walks with a proper stride: shoulders roll, a little bounce, the gun
  carried low at his side, his fist on the leash, and he leans back when the dog pulls.

## 0.8.0 — merge with the ChatGPT pass, fixes, painted art, new score

- **Merged** main's story rewrite, hit/fall/death reactions, boss polish and kill
  feedback; fixed what it broke:
  - the procedural synth failed to parse and took all music down
  - the 3D overlay called a missing method and drew a dark band
  - breathing undid the idle poses
  - letterbox bars covered the VHS counter
- **Painted art** (assets/art/Artwork, imported by tools/art/import_artwork.py):
  - title key art
  - apartment and Channel 9 cutscene frames
  - ten painted dialogue portraits
- **Enemies can always be killed:**
  - a downed enemy can no longer be dragged into another state half-downed
  - any hit on a downed enemy finishes it
  - heavies go down to a flurry of three punches
- **Forgiving aim:**
  - melee turns into a target in front of you and has a little more reach and arc
  - a shot within about 12 px of a body goes to it
  - no lock-on
- **Checkpoints:**
  - VHS cassette popup (PLAY) and REWIND on respawn
  - 2.5 s grace after respawn: no enemy sees or hears you until you attack
  - enemies are back at their posts, facing the way they were placed
- **Sleeping dogs** lie on their side; **dozing guards'** chairs no longer turn.
- **Kill-on-the-beat bonus removed.** The music still follows the action.
- **Level scores v3:**
  - 32-bar stereo pieces with intro, verse, pre-chorus, chorus, breakdown and
    turnaround
  - much richer arrangement
- **Installer** kept under 30 MiB: subset fonts, lighter Vorbis, source art
  excluded from the export.
