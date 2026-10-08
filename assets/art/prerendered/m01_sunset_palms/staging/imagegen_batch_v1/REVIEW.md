# ImageGen batch to Blender: first reconstruction proof

The full listed M01 source categories were generated before this Blender pass. This is the first use of the new batch in Blender, not completion of the map or a runtime replacement.

`interiors_material_review.blend` reuses the existing authored staging geometry and packs nine image files. Ten existing material bindings now use reviewed ImageGen sources: wallpaper, carpet, bedspreads, walnut, towels, bathroom tiles and reception floor. `material_bindings.json` records each binding and repeat distance. The original staging blend is preserved.

The Blender 5.2.2 background run completed with Python error exit checking enabled, rendered `interiors_material_review.png` at 1280x720 and reported ten applied materials. The rendered output was inspected directly.

Visible improvements: matching cream wallpaper in guest rooms, coral fan-pattern bedspreads, detailed teal carpet, checkerboard reception floor and wood surfaces. Remaining limitations: simplified chairs and fixture forms, sparse contextual small detail, overly broad staging plinth, inconsistent scene layout versus playable map, material repeat/scale not yet approved, and no gameplay projection/collision integration. The render is a material reconstruction proof; it does not yet reach the approved courtyard target.

No colour texture is treated as validated height data. Roof imagery with baked shadows was excluded. BOX mapping supports vertical surfaces on batched geometry, but stretched/rotated local objects and cloth UVs require further inspection.

Next production work must improve actual prop geometry from the generated references and reconcile the authored layout with reachable objectives and interactive anchors before runtime promotion.
