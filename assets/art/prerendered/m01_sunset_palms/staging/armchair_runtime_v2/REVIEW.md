# Upholstered armchair runtime candidate

ImageGen guest_room_direction supplies the style reference. armchair_sage_fabric_albedo_v1 is a new ImageGen colour source, mapped in Blender at half-metre repeat; no colour-derived height or normals. Four Blender PNGs preserve transparent background, 50-degree elevation and explicit floor anchors at 16 game pixels/metre.

The GPU m01_armchair_scale_review scene loaded all four frames and verified image dimensions, transparent corners and floor anchor transforms. Its capture is enlarged for inspection, not a normal gameplay view.

m01_architecture_game_review replaced 11 armchair visuals in an isolated M01 replay, leaving existing collision bodies and level data unchanged. Prior baked furniture/clutter tiles were hidden only in the review; remaining source items were redrawn. build/m01_room_armchair_candidate.png was inspected: upholstery reads darker than the old props, and the near-wall placement hides part of its projected silhouette. Do not promote yet: light treatment, placement clearance, orientation mapping, contact shadow, normal-zoom readability and collision footprint still need review. Other old furnishings remain visibly inconsistent with the pool reference.
