# Level flow and PixelLab art

The four mission layouts are authored in 16-world-unit ASCII cells in `levels/*.json`. `tools/layout_plans.json` records the reviewed circulation edits, and `tools/polish_layouts.py` applies them. The `tools/build_m0*.py` scripts call that polisher after regeneration.

`#` is an opaque colliding wall; `D` is a walking door; `W` is glass that reveals the next room but blocks walking until shattered and vaulted; `%` is a breakable shortcut; `L` is a scripted locked door. Major perimeter walls remain opaque. Adjacent `D` cells form a wide entry. Furnishings remain map cells and participate in collision and navigation.

The breach, gauntlet and core for each mission are recorded in `layout_design` in each JSON file. The motel joins guest rooms and loops through the courtyard and service rooms to reception. The salvage yard loops through warehouse, kennels and office. The studio has partitioned stage wings and routes through makeup and production. The villa uses a screened foyer to connect its wings and approach Tommy's ballroom.

All 107 existing floor, wall and environmental sprite source images have PixelLab-treated counterparts under `assets/art/pixellab_world/`. `ArtLib` loads these in preference to the originals. The original files remain in place for rollback. The palm, furniture, glass, doors and level decorations use this route; the weather particles prefer the same pack. Extra PixelLab floor decals are placed through each level's `decor` list. Their `floor` flag draws them below furniture and the `size` value controls their visual scale without changing collision. A PixelLab pool-water tile retains the animated caustics and coping edge.

Level topology must stay practical: no enclosed room has a single route out, all mission entities remain reachable from the spawn, exterior walls keep sight-blocking cover, and glass is used for preview and optional breach instead of a required ordinary exit. After editing a map, run `python tools/polish_layouts.py --check`; the Godot smoke, edge, chapter 3 and stress scenes check the game systems.
