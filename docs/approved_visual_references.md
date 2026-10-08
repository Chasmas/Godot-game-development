# Approved visual references

## Pool environment

The user authorizes new fitting additions and improvements throughout every level. Design additions by location and narrative: lived-in maintenance and guest traces at the motel, industrial wear and salvage activity at Yermo, production equipment and backstage traces at the studio, funerary objects and unsettling burial events at Villa. Use intentional placements and environmental motion; preserve traversal, encounter readability, objectives and performance. M01 remains first for completion and review, followed by the remaining maps. This is scope authorization, not evidence that any listed addition already exists.

`assets/art/prerendered/m01_sunset_palms/courtyard_art_target.png` remains the quality reference for environment composition, lighting, material richness, vegetation and deliberately placed props. Finish M01 before extending the environment pass to subsequent levels.

## Mourning angel

## Additional user detail references (2026-10-07)

User-provided images in `C:/Users/gil_n/OneDrive/Ambiente de Trabalho/IMAGENS JOGO/` are visual references, not assets to ship. They supplement the pool and mourning angel:

- `3649787-witchbrook1.webp`: purposeful dense interiors, stocked shelves, layered furniture, warm practical lighting and clear paths.
- `Sem título.png`: restrained night palette, wood grain, fabric folds, tropical vegetation, small surface props and readable localized warm light. Particularly relevant to the motel.
- `df67fe3d-d907-4b15-bc94-dd755b3261a9.jpg`: distinguishable functional furniture, varied containers, shelving and coherent prop clusters.
- `cc344b2f-1fed-4d1f-b019-86580f64ab28.jpg`, `dcfef195-388f-48aa-9246-88ccc9f6d8be.jpg`, and `pixel-art-game-level-background-bit-landscape-arcade-video-game-mountains-trees-platforms-pixel-art-game-level-background-bit-326265746.webp`: stone joints, chips, vegetation in crevices and architecture with volume, useful for Villa without adopting fantasy theming.
- `images.jpg`: varied subdued water surface, shoreline distinction and readable splashes; motion is not proven by this still.
- `isometric-view-industrial-pixel-art-factory-molten-metal-glowing-furnaces-ai-generative-isometric-view-industrial-363065938.jpg` and `StockCake-Automated_Pixel_Factory-2131862-medium.jpg`: coherent pipe runs, equipment hierarchy, cold/warm contrast, machinery and steam, adapted to Yermo's salvage setting rather than turning it into an unrelated factory.

Use their material richness and composition through ImageGen and Blender. Do not copy watermarks, artwork, arbitrary perspective or unrelated themes into production assets. Validate detail at the game's actual scale and preserve actor silhouettes and combat lanes.

On 2026-10-07 the user approved `assets/art/reference/cemetery/mourning_angel_v2.png` as an additional whole-game detail reference: readable anatomy and expression, natural hands, layered drapery with volume, articulated feathers, carved mouldings and believable erosion and moss. Translate these qualities to each asset's appropriate material and purpose. This approval does not approve the simplified Blender angel candidate or its placement.

## Shared ImageGen and Blender pipeline

The user explicitly made this mandatory for every visual asset in the game, including every menu, HUD and popup (2026-10-07). Do not author or promote new visual art outside this pipeline. Audit existing art for replacement where it falls below the approved references. Runtime logic remains in Godot; music and character voices use ElevenLabs. Both ImageGen source and Blender contribution must be traceable, and pipeline use alone is not a quality approval.

Applies to environments, props, characters, UI art and visual effects. ImageGen supplies visual direction, textures and raster assets. Blender supplies authored geometry, materials, animation and rendered sequences. Godot assembles effects, dynamic lighting, timing, audio and gameplay interaction. Use code for appropriate runtime behavior; do not substitute generic shapes for finished visual art.

For fire, smoke, lightning, sparks and blood, review temporal motion and native-scale gameplay readability as well as individual frames. Preserve transparency, avoid visible sprite rectangles and obvious repeating patterns, and ensure effects do not conceal combat information. Validate performance and event timing in the actual level. Pipeline availability is not proof that these effects or FMV cutscenes are finished.

## Laundry material candidate

The mandatory visual pipeline explicitly includes the Inverted Index studio intro and the "Created by Gilberto Lopes" presentation. Preserve the requested minimalist studio symbol and develop its materials, neon contour animation and cinematic presentation. Review timing with its short ElevenLabs chime. Aim for a coherent high-end indie finish throughout; do not label unfinished renders as final quality.

Built-in ImageGen generated `assets/art/materials/m01/laundry_tiles_albedo_v1.png`. Copied unchanged from generated output; Blender binding and runtime placement are pending. Prompt: "Game material asset: one seamless square diffuse albedo texture for the floor of a worn 1988 California motel laundry and utility room. Exact orthographic top-down view, fills entire image edge to edge. A regular aligned grid of eight by eight small square ceramic tiles, muted warm ivory with occasional very pale desaturated mint tiles, thin grey-brown grout. Subtle ceramic grain, tiny chips at a few corners, faint water mineral stains and restrained ingrained dirt in grout, believable carefully maintained but aged surface. High quality physically believable surface detail, restrained contrast for gameplay readability. Uniform neutral diffuse illumination. No perspective, no objects, no borders, no text, no shadows, no specular highlights, no baked ambient occlusion, no lighting gradient, no neon colors, no illustrated outlines. Matching opposite edges for continuous tiling. This is material color data to be lit in Blender and Godot, not a scene."

Seamlessness is requested but not yet verified; do not claim it from the prompt alone.
