# Palm Fresh detergent candidate

Image source: built-in ImageGen, copied unchanged to `assets/art/materials/m01/palm_fresh_label_v1.png`.

Blender geometry: `tools/art/m01_detergent.py` creates elliptical moulded bottle shoulders, neck, ribbed cap and UV-mapped front label. Non-emissive plastics replace the former neon materials in `tools/art/build_m01_interiors.py`. Four tinted bottles rest on the service shelf. Current placement is staging only; no runtime approval is implied.

Validation: Blender 5.2.2 with `--python-exit-code 1` succeeded; `build/m01_detergent_detail_review.log`. Reviewed `m01_service_transition_detail_staging.png`: printed labels visible, no glowing bottles, shelf contact present. Remaining room props and native gameplay integration need further work.

## Exact ImageGen prompt

Production game prop texture: a single vintage 1988 American laundry detergent bottle front label, flat orthographic graphic scan filling the square image edge to edge. Designed for a worn ivory plastic detergent bottle in a California motel laundry. Warm off-white printed paper background, deep teal broad typography, coral-orange small sunburst, navy dividing rules, simple stylized white cotton blossom emblem, tiny believable instruction bars with no readable prose. Main text exactly 'PALM FRESH', smaller 'LAUNDRY DETERGENT'. Distinctive tasteful authentic vintage supermarket packaging, very slight faded printing, small rubbed paper edges and fine surface grain. Centered design readable when reduced to a small game prop, no neon, no glow, no perspective, no bottle, no mockup, no shadows, no surrounding objects, no watermark. This is an albedo label texture to be placed on Blender geometry, not a scene.
