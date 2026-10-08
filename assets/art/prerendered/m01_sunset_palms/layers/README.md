# Sunset Palms preview layers

These PNGs are aligned Blender previews for M01 and are not enabled in the normal
Godot level yet.

- `ground.png`: courtyard slab, pool, water, coping and parking surface.
- `architecture.png`: motel wings, roofs, facade and rails.
- `props_vegetation.png`: furniture, cars, palms, plants and loose dressing.
- `foreground_occlusion.png`: large palms, planters, sign and other possible
  foreground occluders.

Regenerate from the repository root:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender -b assets/art/prerendered/m01_sunset_palms/sunset_palms_courtyard.blend --python tools/art/render_motel_layers.py
python tools/art/audit_motel_layers.py
```

The exporter forces the master `1920×1080` canvas even when the source blend was
last saved after a low-resolution `--pixel` render.

Preview over the live M01 without changing gameplay:

```powershell
$env:GALLERY_MISSION = 'm01_checkout'
$env:GALLERY_PRERENDER = '1'
$env:GALLERY_PRERENDER_LAYERS = '1'
$env:GALLERY_PRERENDER_SCALE = '1.0'
$env:GALLERY_PRERENDER_ALPHA = '0.55'
& $godot --path . res://tools/level_gallery.tscn --display-driver windows --audio-driver Dummy
```

Integration gate: verify pool/parking alignment, wall projection, character
contrast, foreground occlusion, collisions, objectives and navigation in a real
M01 capture before adding these textures to the shipped level.
