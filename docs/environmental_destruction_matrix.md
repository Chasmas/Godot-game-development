# Environmental destruction matrix

This matrix applies the same authored destruction grammar to every level while respecting each map's existing props. It is a visual treatment layer over the Godot damage events; it must not change collision, navigation, objectives or map footprint.

| Level | Existing destruction anchors | Blender / runtime treatment |
|---|---|---|
| **M01 Sunset Palms** | 5 TVs, 2 arcades, 2 vending machines, 8 plants, 2 lamps, 2 fuse boxes, 53 windows, 7 propane tanks, 2 weak walls | Neon glass shards, CRT static, soda spill, palm leaves/soil, emergency lighting, curtain sway, scorch decals and dust after breaches. |
| **M02 Yermo Salvage** | 68 crates, 40 wrecks, 64 cages, 4 dumpsters, 2 propane tanks, 3 fuses, 15 windows, 1 weak wall | Scrap panels detach, sparks and dust, kennel bars rattle, loose tires roll, fuel fire leaves an oily burn mark, fuse arc kills warehouse lights. |
| **M03 KHSC Studios** | 9 TVs, 1 arcade, 2 vending machines, 3 plants, 3 lamps, 2 fuse boxes, 43 windows, 8 propane tanks, 2 weak walls, 26 wrecks | Film lights pop, CRTs smear to static, set dressing collapses in small pieces, prop glass scatters, smoke catches colored stage light, cables swing briefly. |
| **M04 Villa Estrella** | 1 TV, 2 plants, 2 lamps, 1 fuse, 28 windows, 3 propane tanks, 2 weak walls, 24 crates, contextual coffins | Ornamental glass and lamps fracture, coffins break into wood/dust and can release contextual loot, flower petals and soil, gas flare reflection on marble, blackout candles/emergency sconces, weak-wall reveal with masonry chunks. |

## Shared impact rules

- Small firearms produce a visible hit spark, a localized crack/decal and a short sound; they do not move structural geometry.
- Heavy weapons and explosions can complete a prop's damage state, spawn debris/smoke/heat shimmer and leave a temporary scorch or dust mark.
- Breakable props become visually readable in their broken state while preserving their authored collision behavior.
- Destruction must leave the playable lane clear. Debris is decorative, low-profile and pooled against walls or under furniture.
- The final Blender composition should reserve these pockets for particles, decals and broken silhouettes before runtime promotion.

## Validation gate

Before any level receives runtime art promotion: run the level's gameplay smoke coverage, the global visual audit, the relevant Blender/staging audit, and confirm that the destruction pass has no navigation or collision changes.

## Regra transversal de animação ambiental

Todos os níveis devem manter uma camada de vida ambiental ligada ao layout original: movimento contínuo de água/vegetação/ecrãs/luzes e eventos inesperados raros, escolhidos pelo contexto do mapa. O `AmbientEventDirector` é instanciado por nível; eventos específicos (como a palmeira atingida no M01) são one-shot por sessão, enquanto relâmpagos, trovões e outras variações meteorológicas continuam apenas como atmosfera. Estas camadas não alteram navegação, colisões, objetivos ou rotas de inimigos.

