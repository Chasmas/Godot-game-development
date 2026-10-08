# Armchair v3 placement review

Reuses v2 ImageGen fabric and authored Blender geometry. Higher neutral key/fill illumination and fabric piping replace the previous dark render and wooden-looking seam. Four transparent outputs and their explicit floor anchors are regenerated in Blender.

The actual M01 GPU review replaced eleven visuals. Nine decorative Dressing.ClutterLayer chairs moved six game pixels inward; solid FurnitureLayer pieces were not moved. Candidate origins are checked against actual WORLD/PROP point intersections. Projected silhouette alpha sampling (every four source pixels, threshold .5) now reports zero wall samples for all eleven chairs, versus roughly 25 percent of opaque samples for nine previous placements. This is not a complete footprint/actor-clearance test.

build/m01_room_armchair_candidate.png was inspected after the run: upper-left chair now has a complete silhouette and lighter readable cloth. The wider map remains mixed art styles. Preview only; level JSON, navigation and production visuals remain unchanged. Full collision footprint, clearance from actors/doors, contact shadows and native-zoom readability remain pending.
