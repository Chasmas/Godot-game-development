# M01 native ground

The exact-grid Blender source-colour floor is integrated through M01NativeGround.
ImageGen material sources are baked by Blender; Godot lights remain live.
The water is transparent in this texture and remains animated by the existing game.
Walls, actors, props, navigation, doors and checkpoint interactions remain native.

The resource is an S3TC-compressed ImageTexture saved by Godot (16,990,208 texture bytes).
It uses the original 4352 by 3904 render, scale 0.25, origin zero, z -9.
253 sparse 64-world-pixel drawing tiles share this single resource, allowing
local floor lights to affect each area. Empty regions are omitted; alpha is unchanged.
The original floor remains as fallback. A different level-file SHA256 disables this layer.

Verification:
- Source and decoded compression: zero opaque pixels in 738 water/wall/void cells;
  all 3410 floor centres covered.
- Exact Godot floor parity: 4148 cells, zero mismatches.
- Production GPU scene: native compressed resource loads; all 84 pool centres transparent.
- Eleven native chairs retain accessible sides and clear reachable door swings.
- Existing measured chair collider and its four navigation cells retained.
- Door wall-stop checks at 120 Hz, 50 ms and 100 ms pass; five kick-occlusion checks pass.
- Paired frozen-scene GPU samples: baseline median 24.607 ms / p95 28.169 ms;
  ground median 24.460 ms / p95 27.359 ms. These are not a full gameplay benchmark.

Tiling follow-up with intro dialogue removed: single-sprite median 24.505 ms,
tiled median 24.958 ms. The tiled p95 was higher (35.770 versus 27.835 ms);
frame-time variation needs further gameplay profiling. Lighting is more local
near POOL and Cass than with the map-sized sprite. No extra texture copies are made.

The rest of the architecture remains under review, including wall art and room dressing.
No executable or trailer was generated for this integration.
