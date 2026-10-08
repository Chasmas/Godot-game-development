# M01 direct source visual review

Status: partial visual review; no runtime approval. All 137 generated sources are present, but source presence is not artistic approval. Blender work on this batch remains deferred.

## Inspected sources

- `pool_direction.png`: detailed nighttime motel direction. Oblique perspective and foreground depth blur prevent direct use as a gameplay plate. Reconstruct with the shared production camera and native-scale readability.
- `guest_room_direction.png`: useful furniture and surface detail, but daylight differs from the nighttime courtyard. Resolve lighting in Blender; do not paste the concept into the map.
- `cass_reference.png`: red leather jacket and natural full-body proportions. Soft studio backdrop/halo needs review before any cutout use. Preserve approved identity and portrait treatment during reconstruction.
- `harcourt_reference.png`: useful older-character material and costume reference. Studio halo and realistic rendering do not establish a clean runtime sprite or portrait-style match.
- `crt_reference.png` and `damaged_crt_reference.png`: incompatible intact/damaged models. The intact model has a carrying handle, different control layout, front emblem and opposite exposed side. Damage art is a fracture/material reference only. Both production states must derive from the same Blender model, camera and footprint.
- `guest_door_reference.png` and `damaged_door_reference.png`: related cream/walnut direction, but the damaged state loses the room plaque, peephole and brass kick plate. Preserve identity details and shared door geometry in production; hinge and latch placement must match the gameplay interaction.

## Layout authorization and production constraints

## Corrected source candidates

Two built-in ImageGen edits are saved without replacing original sources. Exact prompts and edit-target paths are in `prompts_wave_16.json`; original output hashes are registered in the manifest.

- `damaged_crt_reference_v2.png`: visually preserves carrying handle, controls, palm emblem, feet, cable and exposed side. Local glass impact and cabinet damage now read as the same television. Suitable as a reconstruction reference; runtime projection and fracture animation remain unvalidated.
- `damaged_door_reference_v2.png`: visually preserves 204 plaque, peephole, lock hardware, bottom kick plate and original framing. Soft studio background/halo remains visible despite requested transparency. Suitable as a geometry/material damage reference only; not approved as a transparent game sprite.

Wave 17 adds four visually inspected identity-preserving corrections: vending, arcade, ice machine and window. The vending machine retains its five shelves, paired controls and coral side graphics. The arcade retains exactly two ivory buttons, its original marquee and coin door. The ice machine retains its original dispensing bay and push control. The window retains both open side curtains and brass rod. The three machines still show studio halos and are reconstruction references only. The window's baked sunset reflection must not become the production nighttime background; glass and environment are separate Blender elements.

`reconstruction_state_pairs.json` selects six reviewed intact/damaged reference pairs. This selects model identity references, not runtime sprites. The batch now contains 143 images including six correction candidates. Other source pairs remain to be reviewed. No full-batch quality approval is implied.

## Layout production constraints

## Material source review

All fourteen materials listed in `material_review.json` were inspected directly. Plaster, wood, wallpaper, tile, carpet, cloth, asphalt, metal and rubber detail are usable directions with explicit UV/scale constraints. No seamless or native-scale approval is claimed. Roof tile imagery has visibly baked curved-surface shading and overlap shadows, so its filename does not justify treating it as neutral albedo for raised roof geometry. The towel loops also contain micro self-shadow; keep relief restrained. Geometry and material response must supply production lighting, wetness, metal exposure and tile joints. No source image was altered in this review.

## Shared layout production constraints

The user explicitly reaffirmed permission to change level layouts to improve gameplay and fun. Evaluate alternate approach routes, readable combat lanes and exploration against objectives before committing a replacement map. Preserve the existing playable layout until collision, navigation, door interactions, enemy placement, surveillance, checkpoints and transitions pass review on the replacement.

Static art may be pre-rendered from Blender. Use the same layout for ground, architecture, occlusion and interactive anchors. Doors, destruction states, actors and gameplay effects must remain independently controllable. Existing Blender courtyard and room work remains reusable.

## Inspection access

The local HTTP server launch was rejected by automatic policy review. The integrated browser rejected the local file URL. Inspection therefore uses the local PNG image-view tool without browser or server workarounds.
