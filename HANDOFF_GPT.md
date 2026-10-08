# Handoff para GPT/Codex — HOTSHOT California

Atualizado: 2026-10-05 ~18:00 (Europe/Lisbon), por Claude. **Começa pela secção 4b** (estado atual e fila).
Lê este ficheiro todo antes de mexer em qualquer coisa. O histórico detalhado está em
`HANDOFF_CLAUDE.md` (secções "UPDATE ..." e a fila "CURRENT QUEUE").

## 0. Regras fixas (do utilizador)

- Repositório: `C:\Users\gil_n\Documents\GitHub\Godot-game-development-codex`, ramo `codex/continue-polish`.
  A árvore está suja de propósito: **nunca** `reset`, `clean`, `stash` ou `checkout` por cima. Sem commits nem push, a não ser que o utilizador peça.
- **Nunca gerar EXE.** O trailer continua em pausa.
- **Estilo consistente em todo o jogo** (o utilizador disse-o explicitamente): tudo passa pelo "tratamento Meshy" (modelo 3D → Blender → desenhado em tempo real com a mesma câmara a 50° e as mesmas luzes). Nada de misturar personagens/props desenhados em estilos diferentes.
- Qualidade-alvo: as imagens de referência do utilizador, resumidas em `docs/visual-quality-target.md` (secção do topo). Vista oblíqua a 3/4, paredes com altura, cenários densos, luz quente contra sombra fria, muito movimento. Adaptado ao neon-noir californiano dos anos 80.
- Nada gerado é aprovado só porque a API respondeu. Revê sempre com uma captura real dentro do jogo antes de integrar.
- Fala com o utilizador em português de Portugal.

### Coordenação com o Claude (importante)

O Claude continua a trabalhar em paralelo (incluindo uma tarefa automática a cada 5 min), em áreas diferentes das tuas.
**Usa o `COORDINATION.md`:** reivindica lá a tua área, não edites o que estiver com o Claude, e regista no log as alterações a ficheiros partilhados.
O `C:\tmp_shots\autopolish.lock` é só da tarefa automática do Claude; não precisas de lhe mexer.
As secções 4 e 5 abaixo (carro, elenco 3D, animais) são do Claude, salvo indicação em contrário no `COORDINATION.md`.

## 1. Ferramentas e chaves

- Godot (consola): `C:\Users\gil_n\OneDrive\Ambiente de Trabalho\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Blender 5.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (o utilizador aprovou usar o Blender para tudo o que melhore o jogo).
- Meshy: chave em `~/.meshy_key`. Créditos: **1388** neste momento; o utilizador disse "usa o que precisares". Os IDs das tarefas ficam em `assets/art/Artwork/3d/<id>/tasks.json`, para nunca pagar duas vezes a mesma coisa.
- PixelLab: chave em `~/.pixellab_key`. Nunca imprimas nem faças commit das chaves.
- Pasta de revisão/rascunhos: `C:\tmp_shots`.

## 2. Como funciona o novo sistema de personagens (já feito e validado)

1. `tools/art/characters3d.json` tem uma entrada por personagem (prompt, textura, altura; `"image"` para image-to-3D; `"humanoid": false` para animais e veículos).
2. `python tools/art/meshy3d.py model|image <id>`, depois `rig <id>` e `anim <id> idle walk run aim melee punch death death_back knocked` → `assets/art/Artwork/3d/<id>/` (pasta ignorada pelo Godot e excluída do export).
3. Blender "bake": `blender -b --python tools/art/render_cast3d.py -- assets/art/Artwork/3d/<id> C:\tmp_shots\bake_tmp\<id> --fps 15 --bake assets/art/cast3d_rt/<id>/<id>.glb`
   - Gera todos os clips do jogo (armed_*, reload_*, punch, melee, smoke, idle calmo, `drive`, `car_exit`) com IK nas mãos.
   - `--mesh <glb>` usa outro corpo no mesmo esqueleto (a Cass usa `rig_newhair.glb`).
   - Atalho: `python tools/art/bake_ready_cast.py` faz o bake de todas as personagens completas que ainda não estão no jogo.
4. Depois: `godot --headless --path . --import`.
5. No jogo: `scripts/player/cast_model.gd` (`CastModel`) desenha o GLB em tempo real num SubViewport de 128 px. Câmara ortográfica a 50°, luzes partilhadas (`CastModel.dress_stage`), contorno de 1 texel e nenhuma renderização fora do ecrã.
   - `CastModel.create(look)` é usado pelo `CharacterVisual` e pelo `Corpse` para qualquer look que tenha GLB.
   - `CAST_BAKED=1` desliga o modo em tempo real, para comparar.
6. Ferramentas de revisão (sempre sem `--headless`):
   - `tools/cast_preview.tscn`: variáveis `CAST_LOOK`, `CAST_AIM`, `CAST_POSE=armed`, `CAST_SCALE`, `CAST_CLIP`, `CAST_PROGRESS`, `CAST_PREVIEW_OUT`.
   - `tools/cast_lineup.tscn`: 8 cópias à volta da Cass numa missão real, mais uma caída e um cadáver.
   - `tools/car_capture.tscn`: chegada do carro (`CAR_OUT_DIR`, `CAR_STEP`, `CAR_DEPART=1` para a partida).

### Estado do elenco

- **No jogo em 3D (GLB pronto):** cass, guard, gunner, hunter, heavy, scout, bellhop, scrapper, security, stagehand, biker, sniper, handler, welder, riot, civilian.
- **Chefes:** boss (Harcourt), fireman (Dutch), buck, burnt (Tommy).
- **Criaturas da missão 4:** zombie, ghoul, cultist, demon.
- **Ainda não foram revistos visualmente um a um.** É a primeira tarefa abaixo.
- `cass_v2` é apenas a dadora do cabelo; não a uses como personagem.

## 3. Decisões do utilizador a respeitar

- **Cass:** manter o modelo ORIGINAL e mudar só o cabelo para comprido, solto, ondulado e ruivo/castanho (como nas cutscenes, `assets/art/Artwork/paint_4k/cass_close.png`). Já está feito com `tools/art/swap_hair.py` → `assets/art/Artwork/3d/cass/rig_newhair.glb`. Não regeneres a Cass.
- **Zoom no jogo:** roda do rato e teclas `+`/`−`, entre 85% e 135%, guardado na definição `camera_zoom` (`scripts/player/camera_controller.gd`). Feito.
- **Idle calmo**, em vez da pose de combate do Meshy. Feito.

## 4b. ATUALIZAÇÃO 2026-10-05 ~17:30 — estado de TUDO (lê isto primeiro)

### Feito e validado (smoke test 0 falhas)
- **Controlos estilo Hotline Miami** (`scripts/player/cast_model.gd`): as pernas e a anca seguem a direção do movimento e a coluna (Spine02/Spine01/Spine) roda para a mira. A mais de 100° de diferença ela anda de costas (clip em reverso). O AnimationPlayer está em modo manual (`advance` por frame) para a torção ficar por cima. Teste: `tools/cast_preview.tscn` com `CAST_POSE=armed CAST_MOVE=<graus>`.
- **Ordem de desenho / atravessar props**: Props, Pickups, Doors e Actors ficam dentro de um nó `YSorted` (`level.gd::_root`). Tudo o que está de pé usa `z_index = 1` e tem a origem na base. A decoração de pé deixou de ter rotação (`rot` passa a `flip_h`). Corrige as mesas de pernas para o ar.
- **Tiros no ecrã oblíquo**: as balas voam e colidem ao nível do chão e são desenhadas à altura da arma (`Bullet.lift`, `CharacterVisual.muzzle_lift()` / `muzzle_tip_global()`). O clarão, os invólucros, o fumo, a mira laser do jogador e o laser do sniper saem da ponta do cano. Verificado com `tools/fire_capture.tscn`.
- **Chefes**: os 4 aparecem em 3D em todas as fases (`tools/boss_capture.tscn`, `BOSS_MISSION=...`). O Harcourt está sentado antes da luta (clip `drive`). O dano depende da arma (`BOSS_WEIGHT` em `boss_night_manager.gd`, cerca de 10 tiros de pistola; os chumbos dividem o peso, por isso um tiro de caçadeira vale cerca de 1,6 e não 8). O Burning Man leva metade.
- **Extintor**: agora é um spray de espuma de 2,5 s na direção da mira (`scripts/levels/foam_spray.gd`). O objeto usa o sprite `prop_extinguisher`.
- **Carro**: aprovado pelo utilizador (ver 4a).

### Feito depois (~18:00, smoke test 0 falhas)
- **Passada sem deslizar**: os clips walk/run/sneak avançam à velocidade real (`NATIVE_SPEED` e `move_speed` no `CastModel`, limite de 0,5 a 4,5×). Falta confirmar em jogo e afinar `NATIVE_SPEED` se ainda deslizar.
- **Rolamento em qualquer direção** (`CastModel`, `roll_mode`): para a frente (virada para o rolamento), para trás e de lado (virada para a mira). É um rolamento procedural: volta completa à cintura, pernas encolhidas e coluna curvada, mais um rasto de "fantasmas" néon rosa→ciano (`CharacterVisual._cast_ghost`). Falta testar de lado em jogo (`tools/roll_capture.tscn`).
- **Bug corrigido**: com o AnimationPlayer em modo manual, `seek` sozinho não posava o esqueleto (afetava as quedas, as mortes, o carro e o rolamento). Agora faz seek um pouco antes e `advance(0.001)`.

### Último pedido, feito (~18:30, smoke test 0 falhas)
- **Andar mais lento**: a Cass passou de 150 para `move_speed = 118` e `sprint_mult = 1.62` em `data/characters/cass.tres`. O sprint continua a cerca de 190. As outras personagens jogáveis mantêm os seus valores.
- **Olhar para onde anda**: o corpo 3D vira-se sempre para a direção do movimento (a andar e a correr). Só se vira para a mira durante 0,6 s depois de um tiro, golpe ou soco (`AIM_HOLD`, `_aim_hold_t`, `_face_angle` em `character_visual.gd`). Ao disparar vira-se de imediato. Isto substitui o "andar de costas" estilo Hotline. A mira laser segue `player.aim_dir`.

### Por fazer (pedidos do utilizador, por ordem)
0. **Extintor**: o modelo 3D Meshy (`prop_extinguisher`, 30 créditos, saldo 1328) já está em `assets/art/props3d/prop_extinguisher.glb`. É desenhado pelo novo `scripts/levels/prop_model.gd` (`PropModel`: prop 3D estático com a mesma câmara e luzes do elenco, renderizado uma vez) a partir de `interactable.gd`, e escondido quando ela o apanha. Smoke test com 0 falhas, mas **ainda não confirmado visualmente em jogo** (missão 4, salão de baile). Falta: verificar escala e posição (`height_m`, `position` em `interactable.gd`) e pô-lo na mão dela durante o `FoamSpray`. O `PropModel` serve para passar qualquer outro prop a 3D: copia `Artwork/3d/<id>/model.glb` para `assets/art/props3d/<id>.glb`.
3. **Gore com o 3D**: quando são atingidos devem sair pedaços e sangue, às vezes a cabeça rebenta, e braços e pernas soltam-se. Os cadáveres 3D (`corpse.gd`) só usam o modelo quando `missing` está vazio. Fazer: no `CastModel`, esconder ossos (escala 0 no Head/braço/perna) conforme `missing`, e lançar pedaços 3D ou sprites com o mesmo estilo (`_gore_kill` em `enemy_controller.gd`).
4. **Cães 3D**: os modelos Meshy já existem (`assets/art/Artwork/3d/{shepherd,doberman,rottweiler,hellhound}/model.glb`), sem rig. O rig automático do Meshy só funciona com humanoides, por isso é preciso criar um rig quadrúpede e clips no Blender (`tools/art/rig_quadruped.py`) e um renderer do lado do `Dog` (`scripts/enemies/dog.gd`).
5. **Fogo feio**: os triângulos amarelos (`FlameFx` em `boss_fireman.gd` e `fire_zone.gd`) devem passar a fogo com mais qualidade (partículas, várias camadas, brilho), no estilo do resto.
6. **Canyon AR (rifle) no chão parece estranho**: o pickup (`weapon_pickup.gd`) desenha o sprite da arma visto de cima e pequeno. Deve ficar coerente com a vista oblíqua (deitado no chão, escala certa, brilho de "apanhável").
7. **Mesas pequenas**: a decoração de mesas com cadeiras é minúscula (`size` no JSON do nível). Isto é da área do cenário (ChatGPT): aumentar `size` dos sprites de mobília de pé.

### Sunset Palms (Blender): próximo passo
O render está a cerca de 70% (ver a secção "Sunset Palms prerender (continuado pelo Claude)" abaixo). Depois de acabar o desgaste, a luz sob a varanda e as poças, o passo seguinte é **cortar o render em camadas alinhadas à grelha do nível** (chão; arquitetura; props que podem tapar personagens com origem na base e `z_index = 1` para o y-sort; luzes/efeitos) e integrá-las em `m01_sunset_palms` sem mudar colisões nem layout, validando em jogo.

### Regras novas importantes
- `project.godot`: `[filesystem] import/blender/enabled=false`. Não reativar. Os `.blend` em `assets/` faziam o import do Godot falhar.
- Ao testar com ferramentas próprias, não definas a mira (`set_aim`) por cima do `Player`: o controlador também a define e a mão e a arma ficam dessincronizadas.

## 4a. ATUALIZAÇÃO 2026-10-05 16:00 — carro aprovado pelo utilizador

- Causa real dos "espelho grotesco" e "sem abertura": o import do Godot abortava por causa do `.blend` em `assets/art/prerendered/`, por isso nenhum GLB era reimportado desde as 14:10. Corrigido em `project.godot` com `[filesystem] import/blender/enabled=false`. **Não reative.** Se um GLB parecer desatualizado, compara a data em `.godot/imported/<nome>.glb-*.scn`.
- Sequência atual: o carro entra em drift (com uma mola no ângulo de deslize), a porta abre (corte com a espessura toda), ela sai pelo clip `car_exit` dentro do viewport do carro, a porta fecha e o jogador assume em idle. Sem volta de "olhar em redor" (o utilizador não queria).
- Armadilhas: nunca fazer seek para o fim exato de um clip importado (dá a volta para o frame 0); usar no máximo 0,995. O `CastModel` só deixa de renderizar quando está fora do ecrã, e não quando está escondido.
- Smoke test: 0 falhas.

## 4. (histórico) carro da Cass

Queixas do utilizador:
- "ela parece deitada dentro do carro em vez de sentada a segurar o volante";
- "sai toda torta e atravessa a porta";
- "o que é aquela coisa em cima à direita, parece um retrovisor gigante";
- "faz o carro entrar com um drift suave e fixe, agora parece aos solavancos".

O que já está feito:
- Modelo 3D Meshy do Eldorado: `assets/art/Artwork/3d/eldorado/model.glb`.
- `tools/art/prep_car.py` (Blender) limpa o modelo, orienta-o, põe-no à escala (4,6 m), separa a porta do condutor como objeto `Door` (origem na dobradiça) e cria o vazio `DriverSeat` → `assets/art/cast3d_rt/eldorado/eldorado.glb`. Verificação: `--check C:\tmp_shots\car3d\prep.png`.
  - O "retrovisor gigante" grande já foi cortado.
  - **Ainda sobra um pedaço pequeno do lado do passageiro, junto ao para-brisas** (vê `C:\tmp_shots\car3d\_prep.png`, vista 0, à esquerda). Afina a regra `flaps` em `prep_car.py`, usando um censo de faces como o que está descrito no próprio script.
- `scripts/levels/car_model.gd` (`CarModel`): o carro num SubViewport com a mesma câmara e luzes do elenco, `set_heading`, `set_door`, e um condutor dentro do MESMO viewport (`add_driver`, `pose_driver(clip, progress, out, turn)`, `driver_screen_global`).
- `scripts/levels/hero_car.gd`: usa o `CarModel` quando existe. `_arrive_3d` / `_depart_3d`: ela vai sentada, roda para a porta, sai com o clip `car_exit` e o jogador assume no ponto exato onde ela fica de pé. O sprite antigo e o caminho antigo continuam como fallback.

O que falta:
1. **Ainda não está verificado no jogo.** A última captura (`C:\tmp_shots\car\_car3d_sheet.png`) mostrava o carro 3D **muito claro/sobre-exposto**, porque o nível dá um brilho extra aos atores. Ajusta a luz ou o `modulate` do `CarModel` para ficar igual aos outros carros.
2. **Pose sentada:** verifica que no clip `drive` ela fica sentada com as mãos no volante (o volante está em `DriverSeat` mais para a frente; afina os alvos de IK `wx, wy, wz` em `render_cast3d.py`, procura `SEATED`). Afina também `seat_at` / `OUT_STEP` em `car_model.gd` para ela ficar no banco do condutor e não atravessar a porta.
3. **Drift na entrada:** reescreve `_drive()` / `route_in` em `hero_car.gd` para uma entrada fluida: curva larga com o carro a deslizar de lado (`_drift`), contra-brecagem e endireitar suave, fumo e marcas de pneu, sem saltos de rotação. Hoje o `_drift` é recalculado de forma brusca a cada passo. Suaviza o heading com um amortecimento por tempo e escreve uma curva de velocidade "entrada rápida → deslize → travagem".
4. Captura com `tools/car_capture.tscn`, faz um GIF e mostra ao utilizador.

## 5. Fila seguinte (por ordem)

2. **Rever cada personagem 3D no jogo** (`cast_lineup.tscn` com `CAST_LOOK=<id>`):
   - escala/altura, legibilidade no escuro, mãos na arma, quedas e mortes;
   - os chefes têm scripts próprios: confirma que `boss_night_manager.gd`, `boss_fireman.gd`, `boss_burning_man.gd` e o do kennel master usam o `CharacterVisual` (e portanto o 3D), ou adapta-os;
   - criaturas: verifica que o zombie, o ghoul, o cultist e o demon usam o 3D (podem ter visuais próprios).
3. **Animais** (shepherd, doberman, rottweiler, hellhound):
   - os modelos Meshy já existem, sem esqueleto. O rigging automático do Meshy só funciona para humanoides;
   - cria `tools/art/rig_quadruped.py` (Blender): esqueleto de 4 patas, pesos automáticos e clips idle/trot/run/bite/death;
   - depois um renderizador do lado do `Dog` (`scripts/enemies/dog.gd`; os cães não usam o `CharacterVisual`) com a mesma câmara e luzes.
4. **Props, cenários, armas e pickups no mesmo estilo 3D** (o utilizador quer consistência total):
   - gerar no Meshy os props mais usados (contados no `decor` de `levels/*.json`) e desenhá-los com o mesmo `dress_stage`;
   - ou fazer o bake em Blender de sprites a 50° com as mesmas luzes, se o custo em tempo real for alto (props estáticos não precisam de viewport ao vivo).
5. **Níveis** segundo `docs/visual-quality-target.md`: paredes com altura, densidade, luzes práticas e animação. Manter 200+ props e as rotas de combate.
6. **UI e cutscenes:** cutscenes até 4K, animadas (preservar `scripts/narrative/story_shot.gd`).

## 6. Validação depois de cada alteração

```powershell
python tools/visual_quality_audit.py
python tools/audio_reference_audit.py
python tools/polish_layouts.py --check
git diff --check
& $godot --headless --path . --import
& $godot --headless --path . res://tools/smoke_test.tscn   # tem de dar 0 falhas
```

- `tools/compile_all.gd` corrido com `--script` mostra "Identifier not found" para os autoloads. É esperado e não é uma falha.
- Os erros `a_star ... out of bounds` vindos de `meat_bone.gd` já existiam antes destas alterações.
- Último resultado conhecido: smoke test com 0 falhas (antes das alterações ao carro 3D, que ainda não foram validadas).

## 7. Armadilhas já encontradas

- O Meshy exporta "triangle soup": soldar os vértices (`remove_doubles`) antes de procurar ilhas de faces.
- As caudas dos ossos dos braços vêm 100× maiores do que deviam; `repair_arms()` em `render_cast3d.py` corrige-as. As animações cruas do Meshy põem os braços por cima da cabeça, por isso faz sempre o bake com IK.
- Os sprites 16 direções pré-renderizados gastam mais de 1 GB de VRAM por personagem. Usar o modo em tempo real (`CastModel`).
- Com `speed_scale = 0` o AnimationPlayer congela a meio do blend entre clips. Para clips controlados por progresso, faz seek em cada frame.
- No PowerShell, `Remove-Item` com padrões que contenham `\d` é bloqueado. Para apagar ficheiros usa Python (`os.remove`).

## Sunset Palms prerender (continuado pelo Claude)

2026-10-05. O Claude (agente de fundo) continuou o render pré-renderizado do pátio do nível 1 enquanto o ChatGPT estava com o limite atingido. Câmara, enquadramento e layout de jogo (alas, piscina, estacionamento) **não mudaram**.

- Build: `& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --python tools\art\build_prerendered_motel.py` (≈15 s em EEVEE, 96 amostras). Para iterar: acrescenta `-- --quick` (meia resolução, grava `courtyard_quick.png`, não grava o .blend).
- Saídas: `assets/art/prerendered/m01_sunset_palms/courtyard_master.png` e `sunset_palms_courtyard.blend`.
- Novo `tools/art/prerendered_kit.py`: construtor de malhas em lote (`MB`, `Frame` de parede) + palmeiras (tronco anelado e afunilado, frondes pinadas curvas, frondes secas, cocos), plantas tropicais, buganvília.
- Fachadas: os detalhes estavam nas traseiras (viradas para longe da câmara). Agora a ala norte e a ala oeste têm frentes de 2 pisos viradas para o pátio (portas teal, janelas com luz quente, cortinas e persianas, candeeiros de parede com luz real, ACs de janela, tubos de queda, conduta, varanda com balaústres, postes e grinalda de luzes). A parede exterior da ala este (a que a câmara vê) tem janelas, ACs e tubos. Os telhados têm platibanda, ACs com ventoinha, condutas, respiros, clarabóias e manchas. Escada paralela à fachada (x 4.6→8.2, y −6.9), com patamar ligado à varanda.
- Props: espreguiçadeiras de ripas com toalhas, mesas e cadeiras de resina, 2 guarda-sóis às riscas, carrinho de toalhas, caixotes do lixo, contentor verde, 8 balizadores com luz, batentes amarelos alinhados com os lugares, boias, chuveiro, máquina de venda e de gelo iluminadas, vasos nas varandas, sinal néon "SUNSET / PALMS / VACANCY" com sol às riscas e palmeira em néon (agora virado para a câmara; antes estava ao contrário) + bloom no compositor.
- Chão: lajes do pátio e asfalto molhado com poças-espelho e **sondas de reflexão planar** do EEVEE (as poças refletem o néon e os carros). Água da piscina com cáusticas (Voronoi) e mosaico.
- Carro: sedan dos anos 80 do Meshy (`prop_sedan80` em `tools/art/characters3d.json`, GLB em `assets/art/Artwork/3d/prop_sedan80/`), usado como carro de hóspede e como sedan abandonado. Custo: **30 créditos** (saldo 1358). O Eldorado não foi alterado.

Progresso Sunset Palms (vs `courtyard_art_target.png`):
```
Vegetação orgânica:      ████████░░ 80%
Fachadas (2 pisos):      ███████░░░ 70%
Telhados:                ██████░░░░ 60%
Props do pátio:          ████████░░ 75%
Estacionamento/carros:   ████████░░ 80%
Sinal néon:              █████████░ 90%
Chão molhado/reflexos:   ███████░░░ 70%
Iluminação/ambiente:     ███████░░░ 70%
Desgaste/sujidade:       ████░░░░░░ 40%
Total vs alvo:           ███████░░░ 70%
```

Próximos passos sugeridos:
1. Desgaste: manchas de humidade e escorridos mais fortes nas paredes, tinta lascada nas portas, sujidade nos cantos e trepadeiras nas paredes da ala este.
2. O piso térreo da ala norte fica quase todo escondido pela varanda; meter mais luz quente debaixo da varanda (já há 4 pontos "Walkway amber") e talvez reduzir a profundidade da varanda (1.1 m).
3. A escada fica quase toda tapada pela palmeira de (8,−6). Se se quiser vê-la, afasta a palmeira e não a escada (a escada tem de bater com a varanda).
4. Telhados: tom mais cinzento-azulado como no alvo, mais folhas e entulho, antenas e parabólica.
5. Poças do pátio: ainda leem um pouco como manchas castanhas. Experimenta `mirror` mais alto com `wet_color` mais claro em `wet_ground(M["deck"], ...)`.
6. Depois: cortar em camadas alinhadas à grelha do jogo (chão / props baixos / oclusores altos). Não foi feito nesta sessão.
