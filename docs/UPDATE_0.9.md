# HOTSHOT CALIFORNIA 0.9.0

## Story
- **Two new missions** close out 1988:
  - **Chapter I-C "Prime Time"**: KHSC Studios, Stage Nine, Burbank, during the live premiere of *HOTSHOT CALIFORNIA*. Studio security and stagehands, a replica of room 204 built as a set, the show's cameras rolling. The boss is **Dutch "The Fireman" Kowalski**, the pyrotechnician who rigged Tommy's car.
  - **Chapter I-D "Sweet Dreams"**: the nightmare. Villa Estrella, a mansion on a hill, and a wrap party attended by everyone Cass has killed. The boss is the burning part of Tommy she kept.
- **Every mission now ends in a scene that explains the next one:**
  - After the yard, Arlo Vance names Dutch and Stage Nine, admits the Director is his brother, and is shot through the window.
  - Before the studio, the Voice reports the ratings and Rudy the floor manager lets Cass in, thinking she's the talent.
  - After the studio, the news reports the fire and the end credits read **EXECUTIVE PRODUCER — T. MORENO**.
  - After the dream, the Voice calls about season two, and Cass pins THE FOOL's Polaroid to her board.
- **New beats in the existing scenes**: a longer prologue (the empty extinguisher), Mom's message on the answering machine, and a funeral-home sponsor on the news.
- **New choices**:
  - Arlo: ask who rigged the car, or accuse him (`arlo_confessed`).
  - The studio: find the Fireman or the control room (`cass_hunts_booth`).
  - The vote: give the audience its ending, or cut the feed (`dutch_spared`). The next day's news reacts.
  - The dream: let Tommy burn out, or hold him (`held_tommy_dream`).

## Presentation
- **Painted cutscenes**: 42 painted frames made with `tools/art/gen_ai_art.py` (OpenAI Images) and animated by `shaders/painted_shot.gdshader`. Each shot has zones for sway, ripple, flicker, pulse, CRT, heat haze, blink, breathing, siren light and drifting fog. The emissive areas breathe, and there is a slow camera move, rumble or handheld wobble. Drawn effects on top include fireworks, dog eyes, a sniper's dot, flying papers and blood rain.
- **In-level scenes** (Harcourt, Dutch, Tommy) play over their own painted, animated frame.
- **New portraits**: Arlo, Dutch, Rudy, Dana, the Director, burnt Tommy and the dead.
- **Painted props and floors**:
  - Top-down cars, beds, loungers, washers, crates, dumpsters, palms, graves, coffins and more.
  - Seamless floors: carpet, tile, wood, asphalt, concrete, grass, dirt, steel, stage floor, marble and rug.
  - Everything is brought down to the pixel characters' density with a palette reduction and an ink outline.
  - OPTIONS › *Painted props & floors* switches back to the procedural look.
- **Chapter shelf**: the two new tapes, with painted covers.

## Weather
Levels pick a preset, and arcade can override it or roll one at random:
- **Night rain** (Mission 1)
- **Desert wind** with dust storms and dry lightning (Mission 2)
- **Santa Ana** winds with embers and ash (Mission 3)
- **Blood rain** with fog and red lightning (the dream)
- **Snowfall**, which settles on the ground
- **Sunny day**, with cloud shadows
- **Fog**
- **Clear night**

Wind carries leaves, newspaper, palm fronds and tumbleweeds across outdoor floors in gusts. There is a wind sound bed, and rain and splashes take the preset's colour.

## Arcade
- New panel with map, mode, modifiers and weather.
- **Modes**:
  - **Score Attack**: the mission as written.
  - **Waves ×5** and **Waves ×10**: the map is cleared and enemies arrive in rows from the far side. Each wave is bigger, with supply drops in between.
  - **Endless**.
- **Modifiers**: infinite ammo, weapon roulette (a new gun every 14 s), melee only, no Spotlight, hard and turbo (the world runs 20% faster).
- Every map + mode keeps its own local top 10. A run's results show the wave you reached.

## Combat
- **The Fireman**:
  - His flamethrower spray is telegraphed and tracks you slowly.
  - Floor fires kill anyone who stands in them, and a dash gets you through.
  - His aluminised suit takes 3 hits.
  - In phase 2 the stage goes up, the sprinklers cough dry and a ring of fire is added.
- **Tommy?**: the Fireman's kit, plus the dead rising around him and a trail of fire.
- **New enemies**: studio security, stagehands, zombies (they sometimes get back up unless burned, blown up or finished), ghouls, demons, hooded ushers and hellhounds.
- **New weapons**: the **Boomstick** (two sawn barrels, huge knockback) and the **Pyro Special** flamethrower (a burning cone that leaves fire behind and never catches you).
- **The dream's tense moments**: graves opening, lights browning out, faces surfacing slowly out of the dark, whispers of things Cass said or heard, doors creaking shut, and a chandelier that creaks and sways before it falls. There are no jump scares.

## Music and sound
- **New music**:
  - *Prime Time*: 4 stems, a game-show brass hook.
  - *The Fireman*: 2 layers; the second is the stage on fire.
  - *Sweet Dreams*: 4 stems, a detuned lullaby on warped tape with a D-against-E♭ drone and reversed ghosts.
  - *Top Billing*: the dream's boss track.
- **New sounds**: wind, fire, flamethrower, ignition, studio applause, a laugh track, the tote-board ding, the ON AIR buzzer and dry sprinklers.

## Tools
- `tools/art/gen_ai_art.py` + `ai_manifest.json`: every prompt in one place. Characters that recur are made from reference portraits so they keep their faces.
- `tools/art/process_ai_art.py`: turns the generated art into the game's files.
- `tools/write_story.py`: the story pass, written as data.
- `tools/build_m03.py` and `tools/build_m04.py`: the new maps.
- `tools/gen_music_ch3.py` and `tools/gen_sfx_weather.py`: the new music and sounds.
- `tools/chapter3_test.tscn`: the new automated test, added to `tools/run_tests.sh`.
- `tools/i18n_pt_additions.py`: European Portuguese for everything new (911/911 strings translated).
