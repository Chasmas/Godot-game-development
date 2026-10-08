# Auditoria de integração PixelLab

## Reaudit 2026-10-07: Yermo steam overlay

The earlier staging description below was stale: `yard_steam_vent_overlay`
was present in the actual M02 decor and its generation plan. Inspection of
both the review candidate and the runtime HQ PNG shows opaque orange clumps,
not translucent steam. Removed this decor entry from both map and plan;
preserved source images for provenance. A replacement with drifting wisps,
soft alpha and depth remains pending. Do not re-promote the existing bitmap.

Replacement integrated later on 2026-10-07: OpenAI-generated alpha texture
`assets/art/vfx/steam_wisp_v1.png`, driven by `steam_vent.gd`, emits three
low-opacity drifting wisps during a nine-second cycle. One authored vent is
attached to the upper connector of the existing floor manifold at (29,26),
rather than the unsupported old location (37,35). Map and layout plan agree;
the plan's stale standing-manifold flag was corrected to match the map.
GPU review loads the actual Decor-created vent and confirms exactly one,
with captures at 0/1.5/3/6.5 seconds. Steam source prompt and provenance:
`build/steam_wisp_review/generation.md`. This validates this single placement;
the rest of Yermo and its atmospheric effects still need visual polish.

Atualizada em 2026-10-05. Esta lista separa ficheiros por estado de integração; um ficheiro gerado não é considerado implementado até o renderer o carregar numa cena real.

## Ativos

- `assets/art/pixellab_world/` — 479 PNGs. Floors, paredes e sprites usam esta raiz através de `ArtLib`; a auditoria de níveis encontra 217 sprites e 300 entradas de decor, sem imports em falta.
- `assets/art/pixellab_ui_v3_approved/` — 181 PNGs. Capas, retratos e pinturas de cutscenes são carregados por `StoryShot`, `Portrait`, intro e título.
- A cobertura narrativa foi verificada em 2026-10-05: os 91 planos usados por diálogos e pela intro têm uma pintura PixelLab aprovada; `static` é o único plano deliberadamente gerado pelo motor. `tools/visual_quality_audit.py` passa agora a falhar automaticamente se uma cena usada voltar a depender apenas de arte antiga.
- `assets/art/pixellab_cast_v3_approved/` — 8 PNGs. Os quatro cães e as suas poses caídas são carregados por `Dog`.
- `assets/art/pixellab_cast_v4/` — clips atuais da Cass, carregados pelo `CastSprite`.

## Pendentes de revisão e correção

- `assets/art/pixellab_cast_v3/` — 44 corpos. Precisam de compatibilização com os clips atuais antes de substituírem personagens em jogo. A Cass fica excluída: os seus clips atuais são a referência aprovada.
- O lote humano `guard`, `security`, `civilian`, `gunner`, `heavy`, `hunter` e `riot` foi retirado do runtime em 2026-10-05 após revisão do utilizador. Embora tecnicamente compatível, misturava cabeça vista do teto com peito/ombros quase frontais, escondia rostos e lia-se como bustos sem braços. Os 14 PNGs e respetivos imports foram preservados em `C:/tmp_shots/rejected_overhead_batch/`; não os voltar a promover. O jogo regressou automaticamente às folhas v4/baked anteriores porque os overrides aprovados deixaram de existir.
- A próxima tentativa deve usar uma perspetiva top-down oblíqua consistente com o jogo, com rosto parcialmente legível, cabeça, tronco e membros no mesmo ângulo. Validar primeiro um único personagem completo em gameplay antes de repetir o lote.
- `C:/tmp_shots/character_oblique_proof/` contém a prova isolada desta correção. As tentativas `guard_alive.png`, `guard_dead.png`, `guard_alive_guided.png` e `guard_dead_guided.png` foram rejeitadas por câmara frontal/lateral ou perda de identidade. `guard_alive_imagegen_guided.png` é o primeiro candidato visualmente coerente: corpo inteiro, rosto legível e ângulo oblíquo consistente. Continua apenas em staging porque o renderer dos NPCs separa tronco, pernas, braços e arma; integrar esta figura inteira diretamente duplicaria membros e quebraria a animação.
- `tools/art/pixellab_character_proof.py` reproduz a prova sem copiar ficheiros para runtime. Os antigos jobs humanos em `pixellab_redo.py` estão agora bloqueados contra geração e `--apply`.
- `assets/art/pixellab_level_density_review/` — lote de props pequenos revisto por dimensão e silhueta. Os candidatos legíveis são `clutter_ashtray`, `clutter_bottles`, `clutter_chain`, `clutter_hubcap`, `clutter_tools`, `motel_hasty_checkout`, `motel_room_key_spill`, `combat_glass_partition`, `combat_poker_table`, `coffee_table`, `studio_bootleg_vcr_v2`, `studio_gaffer_scraps`, `studio_script_trail`, `villa_seating_card`, `yard_chain_cable_spill`, `yard_chopshop_ledger`, `yard_oil_rags`, `yard_parts_tags`, `yard_steam_vent_overlay`, `yard_tail_light_debris`, `yard_tarps_tools` e `yard_weld_sparks`. Continuam em staging até às regras de colocação serem verificadas.
- O restante lote de densidade foi rejeitado para integração direta: símbolos ambíguos, perspetiva frontal/isométrica, leitura incorreta ou repetição visual. Em particular, `studio_dust_beam` parece uma explosão, `yard_dog_station` parece um pedestal, `combat_kicked_door` está de frente, `villa_memorial_curtain` é um arco frontal, e os dois wrecks têm ruído/crosshatching excessivo.
- A regeneração de `motel_power_siphon` e `studio_dust_beam` em 2026-10-05 também foi rejeitada: o primeiro lê-se como uma bobina isolada e o segundo como um cone sólido, não como uma ligação elétrica clandestina e luz volumétrica. Nenhum dos dois deve ser copiado para runtime.
- `assets/art/pixellab_ui/`, `pixellab_ui_v2/` e `pixellab_ui_v3/` — candidatos históricos de UI. Os 57 PNGs de `v3` que não existem na pasta aprovada são variantes de retratos, incluindo tentativas antigas da Cass e a Dana verde já marcada como rejeitada; não representam cutscenes em falta. A Cass atual continua protegida como referência.
- `C:/tmp_shots/redo/` — redraws de revisão. Os cães já foram aprovados; mobiliário e pickups continuam pendentes de comparação visual.
- `C:/tmp_shots/kennel_kit/` — jaula, cama e bebedouro PixelLab. Ainda não estão ativos; serão usados apenas após o kit inteiro ser aprovado e ligado ao renderer do canil.
- `C:/tmp_shots/masks_world/` — 11 máscaras de alta resolução. O Saint corrigido preserva a máscara de hóquei, auréola partida, marca vermelha e laço; as restantes foram aceites como conceitos de menu. O conjunto continua pendente para gameplay porque a perspetiva frontal não serve como overlay visto de cima.

## Aprovados em staging, ainda não integrados

- `C:/tmp_shots/utility_kit/utility_control_panel.png` — painel triplo plano, legível e coerente com o cenário.
- `assets/art/pixellab_level_density_review/motel_stucco_cap_v2.png` — textura de acabamento salmão com desgaste fino; revista isoladamente como candidato de superfície, ainda sem integração no runtime.

## Integrados após revisão

- `fuse_box_on` e `fuse_box_off` foram copiados para `assets/art/pixellab_world/sprites_hq/` e ligados aos dois estados de `BreakableProp`. A imagem ligada mostra aviso e indicadores; a destruída mostra a caixa aberta e danificada. A colisão 10x6, sabotagem, corte de luz, score e efeitos mantêm-se inalterados.
- O kit do canil foi corrigido e integrado: `cage.png`, `kennel_dog_bed.png` e `kennel_dog_bowl.png` estão em `assets/art/pixellab_world/sprites_hq/`. A jaula foi regenerada a partir de uma guia ortográfica e perdeu a perspetiva isométrica rejeitada; cama e tigelas entram pelas regras de `RoomKitsMore`. A captura real `C:/tmp_shots/kennel_kit/m02_kennel_runtime_after.png` confirma as jaulas no nível.
- Os dois retângulos cianos ambíguos no canil eram a bancada `TTT` repetindo a mesa de café genérica. `table_kennel.png` substitui apenas as mesas de Yermo por uma bancada metálica de preparação de ração; os restantes níveis mantêm os seus estilos próprios.

## Incompatíveis ou não aplicáveis

- Folhas de contacto e comparações em `C:/tmp_shots/redo/` não são assets de jogo.
- UI de ecrã inteiro sem transparência não é prop de mundo; só pode entrar por rotas de cutscene/menu.
- O ficheiro `assets/art/pixellab_world/sprites_hq/cage.review.png` é uma cópia de revisão deliberadamente não carregada pelo jogo.

## Ordem de correção

1. Rever e corrigir o kit do canil; aprovar as três peças como uma composição reconhecível.
2. Validar os 48 micro-props por dimensão, alfa, silhueta e contexto; gerar novamente os que não se leem bem.
3. Aprovar UI/cutscenes por clareza do sujeito, escala e consistência com a Cass.
4. Compatibilizar personagens não-Cass, incluindo máscaras vistas de cima para o jogo e retratos de alta resolução para menus.
5. Executar auditoria, testes de navegação e capturas dos quatro níveis.
6. Integrar em massa apenas os conjuntos aprovados, começando pelo kit elétrico e pelo canil.

## Verificação visual de cutscenes (2026-10-05)

`tools/cutscene_contact_sheet.py` regenerou seis folhas em
`C:/tmp_shots/cutscene_audit/` para as 91 pinturas referenciadas pelo runtime.
As páginas 01 e 02 foram inspecionadas visualmente: sujeitos, ação e iluminação
mantêm leitura coerente com a Cass e com o alvo cinematográfico. As folhas são
apenas evidência de revisão; os PNG aprovados continuam a ser carregados pelas
rotas existentes de `StoryShot`/menu.
As páginas 03–06 foram igualmente inspecionadas: não apareceu nenhum frame com
rosto perdido, perspectiva incompatível ou sujeito ilegível que exigisse rejeição.

## Reauditoria visual (2026-10-06)

As seis folhas em `C:/tmp_shots/cutscene_audit/` foram regeneradas a partir das
referências atuais. A página 01 foi revista novamente; retratos, planos de ação e
ambientes mantêm leitura consistente. Não houve alteração de runtime.

## Cass dialogue style correction — 2026-10-06

The job/star route fell back to a photorealistic old Cass while the normal route
used the approved PixelLab portrait. Created an OpenAI built-in image_gen variant
from that PixelLab reference, preserving face/pixel style and adding red leather
jacket plus discrete cheek star. Reviewed output and actual Portrait rendering at
124px alongside Tommy; job route now resolves the approved cass_star.png.
`build/cass_portrait_style_review.log` passes. Asset and complete generation
prompt/provenance recorded in `build/cass_portrait_generation.txt`.
Missing approved mouth/blink variants no longer fall back to incompatible art.
This is a static base correction; authored lip animation is still unfinished.
