# M01 visual quality contract

The reference bar for Sunset Palms is authored isometric pixel-scene detail, comparable to the supplied Witchbrook, stone courtyard and tropical motel references.

Every Blender environment pass must include:

- A coherent isometric composition with reachable objectives, correct collisions and navigation, and camera readability. The user authorizes redesigning the existing layout to fit the art direction and improve gameplay; update visual geometry and gameplay data together and validate the revised layout.
- Layered architecture with readable walls, floors, trims, doors, windows, stairs and transitions.
- Dense authored props: furniture, shelving, signage, clutter, containers, plants, small interactive-looking objects and landmarks.
- Material variation and edge definition so surfaces do not read as flat blocks.
- Localized warm/cool lighting, emissive accents, shadows, occlusion and depth separation.
- Strong foreground/midground/background staging and a clear route for the playable character.
- Consistent palette and pixel treatment across the complete level, including interiors and transition spaces.

A geometry blockout is only a staging artifact for scale validation. It cannot be integrated as final art. Runtime integration requires a rendered visual QA pass and a Godot gameplay smoke pass on the actual level.

## ImageGen-first batch order (2026-10-07)

Generate all M01 visual sources before beginning Blender work on this batch. Present sources in a single gallery per review group of approximately 30 images. Individual area concepts are references for authored reconstruction, not grid-aligned gameplay plates. The existing Blender courtyard and interior assets remain reusable after the complete ImageGen source batch is ready. Layout redesign must revalidate objectives, routes, doors, checkpoints, enemy encounters, surveillance cameras and transitions.

## New quality reference bar
The supplied Sunset Palms reference image is the target bar for the finished M01: dense authored props across the whole map, readable motel architecture and room doors, layered palms and planters, wet reflective paving, pool water with visible tile/readable highlights, string lights, practical lamps, neon sign, strong warm/cool contrast, and a 3/4 isometric composition. Current Blender courtyard work is a partial match; interiors and Godot runtime dressing remain incomplete until they meet this bar.

## Per-level adaptation rule
The detail bar is shared, but dressing is authored per level and area. Do not copy the Sunset Palms prop kit unchanged: adapt architecture, materials, landmarks, practical lights, vegetation, clutter and colour accents to each level's fiction while preserving the same density, 3/4 readability and gameplay-lane discipline.
- M01 Sunset Palms: wet pool deck, palms, motel doors, neon, string lights and parking.
- M02 Yermo Salvage: desert salvage, corrugated metal, dust, kennels, utility hardware and harsh sodium light.
- M03 KHSC Studios: stage trusses, cameras, cables, curtains, monitors and coloured studio fixtures.
- M04 Villa Estrella: stone, stucco, courtyards, gardens, fountains, warm lamps and deep shadow.

## Cross-level coherence
All levels share the same visual grammar: 3/4 camera angle, character scale, contact shadows, outline/highlight material read, prop density, combat-lane clearance, foreground occlusion discipline and pixel treatment. Per-level identity changes the authored content and palette, never the readability or production quality bar.
# Quality bar lock (2026-10-06)

All future level environments, props, effects, characters and UI must meet the Sunset Palms exterior master bar: authored material variation, readable silhouettes, coherent 3/4 perspective, controlled lighting, contextual clutter, and gameplay-safe composition. Each level may use its own palette and motifs, but no area is promoted from Blender staging until it passes the same visual and runtime gates.

The pool courtyard is the project acceptance reference. The interiors and every other exterior zone must reach its detail density, lighting depth, prop specificity and finish before being described as complete.

### Reusable environmental-motion grammar
The motion principles established for M01 carry into every later level: one or two
hero motions, several low-frequency ambient loops, and event-linked reactions to
combat or objectives. Each level must adapt the source—dust and loose sheet metal in
Yermo, monitor scanlines and stage haze in KHSC, fountains and curtains in Villa
Estrella—while preserving the same restraint, readability and gameplay-safe timing.

### Destruição ambiental — ideias aprovadas para o M01

Os props destrutíveis já existentes no mapa (TVs, máquinas de venda, arcades, lâmpadas, plantas, caixas de fusíveis, janelas, paredes frágeis e tanques de propano) devem receber uma leitura visual Blender coerente com o estado Godot após impacto:

- TV/arcade: vidro rachado em estrela, faíscas curtas, CRT a apagar para estática e fumo fino a subir.
- Máquina de venda: vidro partido, latas a cair e uma poça de refrigerante refletindo o neon.
- Lâmpadas: estilhaços no chão, luz a piscar duas vezes e cone de iluminação a morrer.
- Plantas e vasos: folhas espalhadas, terra no pavimento e vaso tombado; explosões deixam folhas queimadas.
- Caixa de fusíveis: arco elétrico azul/amarelo, tampa pendurada e corredor que fica apenas com luz de emergência.
- Janelas: fragmentos brilhantes, cortina a balançar pelo impacto e reflexo de neon interrompido.
- Parede frágil: reboco a cair em três ondas, poeira volumétrica e passagem revelada sem alterar o footprint de navegação.
- Tanques de propano: clarão, decalque de fuligem no piso e pequenas brasas que apagam gradualmente.
- Props metálicos (máquina de gelo, carrinho de lavandaria): ricochete sonoro, amolgadela visível e vapor/condensação libertado.

Estes estados são uma camada visual sobre os eventos destrutíveis já implementados no Godot; não devem mover paredes, objetivos, colisões ou a navegação. A composição Blender final deve reservar espaço para os decals, partículas e destroços sem bloquear o corredor jogável.

## Interior promotion checklist (2026-10-06)

Before any guest, service or reception Blender layer enters Godot, verify:

- 3/4 camera preserves door, objective and combat-lane landmarks.
- Props read as authored objects at 100% and at pixel-preview scale.
- Practical lights create readable foreground/midground/background separation.
- Floors, walls and trim show material variation without noisy banding.
- Visual density matches the approved Sunset Palms pool courtyard reference.
- M01 smoke, layout and prerender-isolation audits pass after one-zone promotion.

Until every item passes, keep the layer in staging/ and leave live Godot art authoritative.

### Layout fidelity (mandatory)
Blender may replace the visual treatment of a zone, but it must preserve the original Godot footprint, door/route landmarks, collision lanes, encounter positions and objective pacing. Do not move gameplay geometry to make a render fit; align the render to the level. Validate every promoted zone in a live composition before integration.

### Final environmental motion pass
The composed M01 scene should include small readable ambient motions without blocking
combat or navigation: CRT televisions cycling imagery, slow water drips from selected
service pipes, subtle pool/wet-floor reflections, and occasional practical-light
flicker. Validate these effects in the full Godot composition with Cass, the car
arrival, enemies and objectives visible.

Use variation by context: a lobby CRT can roll through a motel advert and briefly
lose sync; a service pipe can form a droplet that hits a metal tray and creates a
small ripple; laundry steam can catch a cyan strip light; pool neon can travel across
wet tiles and a floating ring can drift a few pixels; a damaged sign can buzz once
when the phone phase begins. Keep each cue sparse, loop-safe and subordinate to
combat readability.

Additional M01 cues: the ice machine can pulse its indicator and release a tiny
burst of condensation; a loose motel key tag can sway when the player passes the
reception desk; palm fronds can cast a slow moving shadow from the pool light; car
headlights can sweep across the wet parking bays during the arrival and escape; a
laundry fluorescent tube can stutter once after a nearby gunshot; and puddles can
carry a brief circular ripple when a heavy enemy lands nearby.

Further optional cues: moths orbiting warm sconces; a vending-machine display
cycling one pixel row at a time; pool-filter bubbles rising near the drain; a phone
cord gently settling after it rings; a door chain trembling when the breach charge
goes off; neon colour sliding across parked-car roofs; and a roof gutter sending a
short runoff stream toward the courtyard drain. These should be event-driven or
low-frequency loops so they enrich the scene without becoming visual noise.
