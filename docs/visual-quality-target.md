# Visual Quality Target

## 2026-10-05 art direction update (user references, re-sent to Claude)

The user's references, to be ADAPTED to HOTSHOT's 1980s California neon-noir (not copied):
- Sea of Stars style 3/4 high-oblique scenes: wooden decks, palm trees, string lanterns,
  warm window light pooling on dark floors, characters with soft contact shadows.
- A cozy witch shop cutaway (3/4 view): walls with visible height and thickness, shelves
  packed with small readable objects, rugs, stairs, a glowing centrepiece, lamp posts
  outside, snow/weather around the building.
- Isometric dungeon/courtyard pieces: stone walls with depth, moss and vines, braziers and
  torches with flickering orange light against blue-violet shadow, puddles/water.
- An isometric lab/office kiosk: tidy counters, monitors, stools, plants along wall tops.
- Industrial foundry/factory: molten glow, pipes, smoke plumes, spotlights cutting through
  dark blue air, robotic arms (animated machinery).

What to take from them:
- Camera: characters and props read as a ~50° high oblique (front faces and tops both
  visible), consistent with the oblique 3D cast (rendered at 50°, 16 facings).
- Walls have height: draw front faces/thickness, not only top lines.
- Density: every room packed with grouped, readable props; no empty floor expanses.
- Light: warm practical sources (neon, lamps, TVs, fire) against cool blue/violet ambient;
  glow and bloom on sources; light pools on floors.
- Motion: things move — smoke, steam, flicker, water, fans, neon buzz, machinery, foliage.
- Blender is approved for making props, set pieces and lighting studies at the same 50°
  camera as the cast (tools/art/render_cast3d.py camera settings).

The older notes below (top-down, density-only) are superseded where they conflict.

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
## Regra permanente de props

**GATE OBRIGATÓRIO — aplica-se ao nível inteiro:** nenhuma área, prop ou composição pode ser marcada como concluída se ficar abaixo do padrão visual aprovado da piscina e das referências do projeto.

A arte é parte do design do jogo. Nenhum prop deve ser apenas uma forma geométrica com uma cor plana: cada objeto precisa de silhueta legível, função reconhecível, volume, materiais separados, pequenas peças funcionais, variação de superfície, desgaste e sombra/contacto. O padrão aplica-se a exteriores, interiores, destrutíveis, pickups, personagens e elementos de cenário em todos os níveis. O layout e a jogabilidade continuam a ser preservados enquanto a densidade visual sobe.

O posicionamento é validado com a mesma exigência: escala coerente com o espaço, base apoiada no chão, distância correta das paredes, portas e circulação, linhas de visão preservadas, ausência de clipping e relação intencional com os props vizinhos. Um objeto bem modelado, mas mal colocado, não passa a revisão.

## Regra permanente de efeitos

**GATE OBRIGATÓRIO — nenhum efeito pode ser marcado como final se parecer uma pintura ou sobreposição 2D simples.** Relâmpagos, fogo, fumo, água, chuva, partículas, destruição e animações ambientais devem ter integração espacial: volume percebido, iluminação sobre o cenário, sombras/contacto, variação temporal, materiais coerentes e composição com os objetos vizinhos. Previews técnicos podem usar formas provisórias, mas têm de ser substituídos antes da integração final.
