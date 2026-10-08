# M01 interior 4K review renders

These PNGs are Blender staging outputs for visual review only. They are not runtime layers.

Generate or refresh them from the repository root:

```powershell
$env:M01_INTERIOR_4K='1'
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --python tools/art/build_m01_interiors.py
python tools/art/audit_m01_interior_4k.py
```

Expected gate: three RGB/RGBA renders at 3840x2160. Promote to Godot only after the M01 visual review approves the interior detail against the Sunset Palms pool courtyard reference.
