# M01 ImageGen-first batch

Execution order required by the user: generate the entire map's visual sources, show them in galleries of about 30 images, then begin Blender work on these sources. All listed category sources have now been generated and indexed in five gallery groups. Blender reconstruction has begun with a non-destructive interior material proof at `assets/art/prerendered/m01_sunset_palms/staging/imagegen_batch_v1/`. Source QA and runtime approval remain incomplete; no complete map integration is claimed.

The user explicitly authorizes redesigning level layouts to fit the art direction, provided the game remains functional. The existing grid is a starting point rather than an immutable constraint. Any redesign must preserve narrative progression and reachable objectives, and revalidate collision, navigation, doors, checkpoints, enemy placement, surveillance and transitions. Update gameplay data and visual geometry together; do not merely stretch a scene image over the old layout. This authorization does not change the ImageGen-first production order.

The user also explicitly authorizes pre-rendered backgrounds where useful. Render static architecture and ground in Blender into aligned layers; keep moving actors, interactive doors, destructible props and event effects separate. Validate camera projection, scale, actor occlusion and collisions against the same authored layout. A concept image with arbitrary perspective is not a production background. This permission does not bypass finishing the ImageGen source batch first.

The first gallery combines material albedos, area direction images and individual prop/character references. Area images establish detail and finish; they do not match the gameplay grid and must not be shipped as level plates. Character reference images are not animated character assets.

Generated sources are preserved unchanged. `prompts_wave_01.json`, later prompt waves, `manifest.json` and `inspection.json` record provenance and technical inspection. Opposite-edge matching is requested in material prompts but requires actual seam review. Transparency inspection is not visual approval.

## Full-map coverage remaining beyond the first gallery

- Bathroom fixture set and complete bathroom direction; service alley and back office direction.
- Architecture: trims, railings, stairs, window damage, door damage, wall breach states and signs.
- Props: bedside lamps, dresser, telephone, rotary phone, service bell, key rack, ledgers, ashtrays, bottles, litter, open suitcases, ice buckets, coolers, pool floats, dumpsters, utility and fuse boxes, arcade machines.
- Vehicles: Cass's red car, parked vehicles, entry/exit interaction details.
- Vegetation: bougainvillea, varied palms and planters, damaged/burned states.
- Cast: remaining enemy kinds, handler, dog, biker and boss; preserve existing approved identity references. Civilians must remain recognizably noncombatants.
- Interaction and effects: water motion reference, steam, glass shards, sparks, dust, smoke, fire, blood and destruction states; these require subsequent Blender animation and in-game timing checks.
- Level-specific collectibles and checkpoint visuals. Shared HUD and menu work remains part of the overall game scope.

Thirty images constitute a review group, not completion of the whole-map art batch. Blender remains deferred until full-map ImageGen coverage is finished.

## Texture and detail scope

The user explicitly requests textures and all feasible contextual detail. Cover wood grain, plaster aggregate and repairs, tile glaze and grout, cloth weave and folds, painted metal wear, rust, glass, rubber, labels, paper and material-specific grime. Avoid identical noise pasted onto every surface. Surface data must remain separate from scene lighting; albedo-derived bump is only an approximation and not a validated height map. Review seamless tiling and native game-scale readability before promotion. Interactive props need compatible intact and damaged state references and later Blender geometry/animation. Details must support function and setting without concealing actors or combat lanes.
