# Static ground layer: Blender to Godot review

`render_m01_ground_layer.py` exports `ground_layer_candidate.png` at 1088x976, one output pixel per Godot world pixel, with origin (0,0), uncentred sprite and scale 1. The source floor geometry derives from the verified runtime floor grid. Water meshes, walls and all interactive objects are excluded; PNG alpha leaves their regions uncovered.

Blender 5.2.2 completed the export. `tools/m01_ground_layer_review.tscn` runs a real M01 instance with a separate temporary save path and captures baseline/candidate images under `build/`. The final run exited successfully and both the original and corrected candidate captures were inspected directly.

The first review used z=1 and obscured low props. Corrected preview z=-9 puts the plate above floor chunks (z=-10) while preserving actors, low furniture, props and the live pool. This correction exists only in the review scene; the normal game does not load the candidate.

The corrected capture shows the pool opening aligned with the existing live water and visible Cass, loungers, pickups and objects. Lighting/texture readability is not approved: the candidate appears too subdued and soft in the courtyard, and room-floor style is still different from existing architecture. Narrative UI partially covers the capture. Additional lighting, scale and scene-dressing work remains necessary before promotion; this is evidence of layer composition, not final art quality or full gameplay validation.

No EXE or trailer is generated. The active full-game work remains incomplete.

## Neutral-colour high-resolution revision

Version 2 exports `ground_layer_candidate_v2.png` at 4352x3904, four texels per Godot world pixel, with scale .25. The existing version 1 PNG and contract remain preserved. Blender renders the source colour through emission with Standard colour management, avoiding a physical lighting pass that would be multiplied by Godot lights a second time. The physical reconstruction blend is not changed by this temporary export shader.

The Blender export completed successfully, followed by a successful actual Godot review run. Direct inspection of the corrected capture confirms more readable paver joints and carpet motifs, preserved live water and visible actors/low props. `build/m01_ground_candidate.png` is the latest actual-game capture. Narrative call UI still overlaps the courtyard. Full scene quality, actor contrast, seams, runtime memory costs and interaction validation remain pending; the new layer remains preview-only.
