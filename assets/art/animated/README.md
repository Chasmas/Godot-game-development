# Rendered animation drop

Blender exports are optional and are consumed by Godot without replacing the
reviewed stills until a complete folder is present.

* Cutscenes: `cutscenes/<dialogue_id>/frame_0001.png ...` at 16:9.
* Portraits: `portraits/<speaker>/frame_0001.png ...` (square or portrait).

The game detects these folders at runtime. Cutscene playback uses `fps` and
`loop` fields from the dialogue root when present; otherwise it uses 12 fps and
plays once. Portraits use an 8 fps loop and keep the existing procedural face
when their folder is absent. Keep the frames transparent only for portraits;
cutscene frames should include their own lighting, rain, fire and camera work.

Run `python tools/validate_animation_pipeline.py` before committing a render.

Runtime cutscene activation now requires `sequence.json` with `approved: true`,
`frame_count` matching all loaded frames, `fps`, and `loop`. A full-scene film
must declare `whole_scene: true`; a per-shot sequence lives in
`cutscenes/<dialogue_id>/<shot_id>/` and declares `shot: <shot_id>` instead.
Unapproved sequences remain staging assets and cannot shadow dialogue shot cuts.
Current apartment/news camera-move previews are explicitly unapproved: they do
not animate characters. Do not mark them approved to satisfy a file-count check.
