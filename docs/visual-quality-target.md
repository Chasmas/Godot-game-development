# Visual Quality Target

The reference images define a density target, not a camera change. The game remains top-down and readable for fast combat.

## Shared rules

- Use a three-value material read: dark outline, local material colour, one bright highlight.
- Give every large room one visual anchor, one functional obstacle, and two small story clusters.
- Keep a clear 2-tile combat lane around doors, windows, objectives, and escape loops.
- Use warm practical lights against cool ambient shadows; reserve saturated red for danger and blood.
- Place small props in intentional groups of 2–4, with variation in rotation and scale, never as a repeated grid.
- Every character gets a readable silhouette, distinct hair/headwear, one costume accent, and a contact shadow.

## Interior target

Walls receive a material pass (paint, tile, wood, or concrete), a light source, and a lived-in cluster. Functional props use PixelLab sprites first; procedural shapes remain only for tiny effects without a matching asset.

## Exterior target

Perimeters use three layers: structural edge, cover/obstacle layer, and atmospheric layer. Yards and streets get unique landmarks such as signage, utility hardware, stains, plants, cables, or vehicle parts rather than repeated vehicles.

## Character target

PixelLab torso art must preserve the existing gameplay rig for legs, hands, weapons, and hitboxes. Poses are checked for shoulder alignment, weapon placement, and a grounded contact shadow before promotion.

## Acceptance checklist

- No room has a single exit.
- No objective is blocked by decoration.
- No prop overlaps a wall edge unless it is explicitly wall-mounted.
- No generated asset is promoted without transparent background and native-size review.
- The scene reads at 100% scale before colour grading or CRT treatment.
