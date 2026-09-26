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
