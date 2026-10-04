# PixelLab level design blueprint

This blueprint applies to the four existing missions. It keeps the established 16-unit grid, circulation loops, objectives and enemy logic. New dressing belongs on wall-adjacent cells or visual floor layers only: it must never occupy a door, a glass breach, an objective, a pickup lane or a combat turning circle.

## Shared visual language

The camera remains top-down and readable at combat speed. Materials use dark value masses with a small number of emissive accents: indigo shadow `#11162B`, near-black outline `#090B14`, oxidised steel `#4A4C4F`, warm practical amber `#F2A65A`, neon magenta `#FF3D7F`, cyan `#35E0FF`, warning yellow `#FFD23F`, and desaturated paper `#B8AA8B`. Light falls down-right from practical lamps; cyan rim light enters from exterior glass, while magenta signs bleed softly onto the nearest wall and floor. Keep 70% of every room in shadow or midtone, with bright values reserved for routes, interactables and focal props.

## Mission art direction

### M01 — Sunset Palms

**Mood and lighting.** A humid coastal motel after rain: salmon stucco, chlorinated cyan reflections, bruised violet asphalt and dying magenta vacancy neon. Pool caustics crawl onto the south-facing coping; room windows cast thin blue rectangles down-right. Exterior lamps make tight amber cones rather than lighting the whole courtyard.

**Three silent stories.**

1. A housekeeper abandoned a trolley between rooms: folded towels, an ice bucket and a single room key tell the player the shift ended suddenly.
2. Behind reception, a bypassed ice machine runs from an illegal extension lead; wet cardboard and a maintenance invoice imply the manager has been stealing power.
3. Near the pool, a failed birthday setup has one wet paper cup, a snapped plastic flamingo and a dragged lounger pointing toward a broken glass escape route.

**Density plan.** Structural: cracked stucco cap, pool coping, rain-dark asphalt seams. Functional: housekeeping cart, ice machine, towel rack, patio table. Micro: wet towel, key tag, paper cup, cigarette butt, slipped motel leaflet. Overlay: rain run-off, palm-frond shadow, pool glare and tiny steam from the ice condenser.

### M02 — Yermo Salvage

**Mood and lighting.** Wind-scoured salvage yard at late blue hour: baked concrete `#8B7861`, rust `#8D4A32`, dusty olive `#596143`, oil black `#171614` and welding cyan `#68E7FF`. A low sodium lamp throws long shadows down-right; intermittent arc-welding flashes make the steel edges pop for a frame.

**Three silent stories.**

1. A stripped sedan has a child-seat buckle still hanging from the rear door; numbered parts tags show it was dismantled in a hurry.
2. A guard has built a dog-handling station from a water bowl, a chewed lead and a warning placard; the untouched bowl signals that the dog was moved minutes ago.
3. A hidden battery charger drains power through two improvised clamps, with a stained ledger under an upturned crate marking stolen catalytic converters.

**Density plan.** Structural: corrugated steel, chain gate, patched concrete and tire-rutted dirt. Functional: welding cart, engine hoist, parts bins, stacked windscreens. Micro: lug nuts, cable ties, oily rags, broken tail-light shards, loose washers. Overlay: drifting dust, welding sparks, exhaust heat shimmer and a raven crossing a power line.

### M03 — KHSC Studios

**Mood and lighting.** A failing television studio split between broadcast glamour and service-corridor grime: matte charcoal `#21202B`, camera-blue `#319ED2`, broadcast red `#F34244`, hot lamp amber `#FFC66D` and stale carpet plum `#48304B`. Key lights point down-right across the stage; cyan monitor bounce lights the opposite edge of props. Keep backstage mostly dark, with taped floor arrows catching the eye.

**Three silent stories.**

1. A presenter fled mid-broadcast: script pages trail from a makeup desk to a toppled headset beneath an ON AIR sign.
2. The prop department is faking a disaster scene with scorched flats, a smoke canister and a continuity photo marked in grease pencil.
3. A junior technician is siphoning a studio feed through a cable spool into a battered VCR, surrounded by labelled bootleg tapes and a cooling desk fan.

**Density plan.** Structural: scuffed acoustic flats, cable trenches, taped stage borders and smoked glass. Functional: camera dolly, boom microphone, flight case, light stand, makeup station. Micro: gaffer-tape curls, film leader, broken pencil, earpiece, coffee stirrer. Overlay: dust in spotlight cones, monitor scanlines, low stage fog and dangling cable silhouettes.

### M04 — Villa Estrella

**Mood and lighting.** Wealth curdled into a haunted garden party: green-black foliage `#182D28`, marble cream `#D7C9A5`, dried-wine red `#772840`, candle gold `#E9B85D` and nocturnal navy `#15172E`. Moonlight enters from the upper-left through garden windows; candles throw short down-right shadows and warm pools that do not flatten the ballroom.

**Three silent stories.**

1. A champagne tower remains half-set for a guest who never arrived: one chipped coupe, wilted orchid and a typed seating card reveal the host’s fixation.
2. The groundskeeper has been sleeping in the service alcove, evidenced by a thermos, pruning gloves and a folded newspaper beside the orange-tree planter.
3. A memorial has been hidden behind a curtain: rose petals lead to a marble bust, a child’s music-box key and a candle burned down to wax tears.

**Density plan.** Structural: veined marble, wrought-iron screens, damp garden walls and parquet repair patches. Functional: grand piano, tea service, fountain, coat check, candelabra. Micro: dropped petals, matchsticks, bottle corks, orange peel, wax beads. Overlay: drifting moths, fountain mist, vine silhouettes, candle smoke and moonlit leaf shadows.

## PixelLab production categories

| Category | Use | Rules |
|---|---|---|
| A — Structural | Wall caps, floor foundations, doors, glass, garden screens and large facade material | Generate seamless top-down textures at 128x128 or 256x256. Keep contrast subtle so navigation reads first. |
| B — Functional props | Furniture, machinery, cover anchors, interactables and large set pieces | Generate at 64x64 or 128x128 with an isolated alpha background. Props that block navigation need their footprint checked before placement. |
| C — Micro-clutter | Papers, screws, leaves, puddles, wires, wax, tags, cigarettes and cracks | Generate at 32x32 or 64x64 with isolated alpha. Place in small story clusters, never as evenly spaced noise. |
| D — Atmospheric overlays | Steam, dust, rain run-off, foliage shadows, smoke, screen glow and falling debris | Generate at 64x64 or 128x128 with soft alpha and no hard rectangular edge. Render above floor decals but below characters unless the effect crosses the camera. |

## Ready-to-use PixelLab prompts

1. **Structure — 128x128:** `Pixel art style, rain-soaked 1980s motel stucco wall cap and poolside concrete foundation, made of faded salmon plaster and chipped pale concrete, featuring hairline cracks, dark rain streaks, tiny rusted screw heads and a faint cyan pool-light reflection, top-down orthographic lighting with a soft magenta neon bleed from upper-left and shadow falling down-right, clean outlines, seamless tileable texture with no objects or text.`
2. **Main prop — 64x64:** `Pixel art style, battered television-studio camera dolly, made of painted steel, rubber wheels and coiled black cable, featuring gaffer-tape repairs, a scratched KHSC inventory plate, dust in the wheel hubs and a small red tally light, top-down orthographic lighting with cyan monitor rim light and warm spotlight highlights, clean outlines, asset isolated on transparent background.`
3. **Micro-clutter — 32x32:** `Pixel art style, small cluster of motel evidence clutter, made of wet paper, plastic and metal, featuring a curled room-key tag, torn pool-party invitation, cigarette butt, water droplets and a bent bottle cap, top-down orthographic lighting with cyan reflected pool light and a tiny amber lamp highlight, clean outlines, asset isolated on transparent background.`
4. **Micro-clutter — 32x32:** `Pixel art style, salvage-yard repair debris cluster, made of oxidised steel, oily rubber and dusty concrete grit, featuring loose lug nuts, cable ties, a frayed copper wire, black oil droplets and a cracked tail-light shard, top-down orthographic lighting with cool welding-blue edge light and shadow falling down-right, clean outlines, asset isolated on transparent background.`

The generation queue and intended placements are recorded in `tools/art/pixellab_level_density_manifest.json`. After a generated asset is reviewed, save it under `assets/art/pixellab_world/sprites/`, add a single `decor` entry, then run `python tools/polish_layouts.py --check`.

## Combat flow blueprint

Every mission uses a breach, gauntlet and core. Doors form predictable, dangerous chokes; rooms retain two or three exits for a flank; glass exposes a threat before becoming an optional loud breach. M01 funnels reception pressure into the pool circuit, M02 uses salvage stacks and kennel sightlines, M03 uses stage wings and backstage glass, and M04 turns the foyer into the switchback before the ballroom.

Killzones are the open mouths of these loops: the motel courtyard, yard vehicle lanes, studio stage crossings and villa foyer. They are deliberately exposed, but each has a door, vaultable furnishing, breakable glass or a side route for bait-and-turn play. Enemy patrols remain readable through glass and door sound; explosive tanks, kicked doors, destructible props and power switches create tactical reversals rather than static cover.

### Before and after combat

Before a fight, rooms show composed papers, glassware, cables, tools, towels and story clusters. After it, the active effects system adds bullet impacts, glass shards, casings, blood pools and sprays, scorch decals, debris, broken props and displaced bodies. Tables remain vaultable; doors can be slammed; intact windows block bullets and sight until shattered; explosive tanks punish crowding.

### Combat PixelLab prompts

1. **Breakable partition — 128x128:** `Top-down pixel art style, breakable smoked-glass studio partition, featuring cracked safety glass, aluminium frame bolts, gaffer-tape repairs and scattered shards at the base, vibrant cyan and magenta neon accents, harsh shadow cast down-right, clean outlines, isolated asset on transparent background.`
2. **Interactive door — 64x64:** `Top-down pixel art style, heavy wooden motel door caught mid-swing, featuring splintered kick mark, brass chain lock, bent handle and fresh bullet holes, vibrant magenta neon accent, harsh shadow cast down-right, clean outlines, isolated asset on transparent background.`
3. **Combat clutter — 64x64:** `Top-down pixel art style, poker table covered in money, cards, broken glass, powder lines and bullet holes, featuring an overturned ashtray and spent casings, vibrant teal and crimson neon accents, harsh shadows, clean outlines, isolated asset on transparent background.`
4. **Gore overlay — 32x32:** `Top-down pixel art style, gritty blood smear with spent shotgun shells, featuring directional shoe drag, tiny glass shards and dark pooled edges, high-contrast crimson neon accent, harsh shadows, clean outlines, isolated asset on transparent background.`
