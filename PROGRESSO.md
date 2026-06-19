# PROGRESSO — VAULTBREAKER

Registro de onde o desenvolvimento parou. Fonte de design: `GDD.md`. Regras de
trabalho: `CLAUDE.md`. Atualize este arquivo ao fim de cada bloco.

**Última atualização:** 2026-06-18

---

## Estado atual: Fase 3 (sistema de armadilhas) — blocos 1 a 4 + UX COMPLETOS

As **6 armadilhas** do GDD implementadas (.tres balanceáveis) + **Caution Mode**,
**Desarme** (Disarming Code), **Retomada** e **menu radial** de seleção. Teste headless:
**37/37 passam**.

### ✅ Bloco 1 — Arquitetura de armadilhas + Bomba/Detonador (`76a9b2d`)
- `StatsArmadilha` (`scripts/stats_armadilha.gd`) como Resource; cada armadilha é um
  `.tres` (dano, raio, knockback, tempos, params). `armadilha.gd` (Area3D) genérica
  ramifica por `stats.tipo`. Acoplamento solto (grupos "armadilhas"/"combatentes",
  `has_method`).
- **Bomba** (não dispara por pisar) + **Detonador** (botão F/B aciona) + **combo**:
  mina e detonador acionam as Bombas do **mesmo dono** dentro do raio.

### ✅ Bloco 2 — Gás, Cova, Painel + efeitos de status (`03cca6d`)
- **Cova**: imobiliza ao pisar. **Painel de Força**: arremessa na direção do plantio.
  **Gás**: auto-emite após um tempo, nuvem ativa por uma duração com dano+slow+imobiliza
  em área (afeta até o dono).
- `combatente.gd`: `imobilizar`/`aplicar_slow`/`fator_velocidade`/`tentar_escapar`
  (button-mash pra sair da Cova); `_process` decai os timers. Player e bot respeitam.

### ✅ Bloco 3 — Caution Mode + bot planta minas (`0aea319`)
- Segurar **C** (teclado) / **L1** (gamepad) liga o modo (contínuo, anda segurando).
  Raio de **2 tiles**: tiles no alcance ficam **azuis**, armadilhas **inimigas** no raio
  ganham **marcador amarelo**. Overlay montado em código (pool de malhas, `top_level`).
- `GridManager.armadilhas_inimigas_no_raio()`. **Bot** agora planta minas simples
  (a cada 4s, teto de 3) — dá alvo real ao Caution Mode.

### ✅ Bloco 4 — Desarme (Disarming Code) e Retomada (`e0367b6`)
- **Desarme**: encostar (≤1,6u) em armadilha inimiga **em Caution Mode** cancela o
  gatilho e abre um **código de 4 setas** (↑↓←→ / D-pad) em **4s**; player fica parado.
  Sucesso: armadilha some, inimigo a perde, Healer **+8**. Falha (seta errada / tempo /
  tomar dano): **explosivas detonam**, demais **re-armam**. Cooldown de 1s.
- **Retomada**: encostar na **própria** em Caution Mode → prompt **R/X** → recolhe e
  devolve **+1** ao inventário na hora.
- HUD: painel do código (setas + timer, acertos entre colchetes) e prompt de retomada.

### ✅ UX — Menu radial de seleção (`c7ec79b`)
- Segurar **Tab** / **R1** abre a roda das 6 armadilhas (player parado); o **direcional**
  escolhe a fatia; soltar confirma. **Q/E** segue como atalho rápido. `radial_menu.gd`
  (Control) desenha as bolhas na cor do `.tres` com nome + contagem; sem estoque, apaga.

### ⏳ Falta na Fase 3
- **IA do bot** usar Caution Mode / desarmar armadilhas do player.

---

## Estado anterior: Fase 2 (vertical slice) — COMPLETA (blocos 1 a 5)

Loop jogável: mover (WASD/gamepad), plantar minas (Espaço/A), o bot persegue e pisa,
toma dano + knockback, com timer de 90s, regras de vitória e HUD. Pronto pra Fase 3.

### ✅ Bloco 1 — Estrutura, arena e grid
- Estrutura de pastas do GDD (seção 14) já existente e em uso.
- **Autoload `GridManager`** (`autoloads/grid_manager.gd`, registrado em `project.godot`):
  - Grid lógico **12×12**, `TAMANHO_TILE = 2.0`, arena centrada na origem.
  - `grid_to_world` / `world_to_grid` / `snap_para_tile`.
  - Ocupação de tiles + lista de armadilhas **com dono**: `registrar_armadilha`,
    `remover_armadilha`, `armadilha_em`, `tem_armadilha`.
  - Validação de plantio: `pode_plantar`, `dentro_do_grid`, tipos de tile
    (LIVRE/VAULT/ESCADA/RAMPA/ESTEIRA) — já preparado pro GDD seção 5.
  - Sinais: `armadilha_plantada`, `armadilha_removida`.
- **Cena principal `scenes/arena/arena.tscn`** (root Node3D + `arena.gd`):
  - Câmera **ortográfica top-down ~60°**, luz direcional com sombra, chão 24×24,
    WorldEnvironment escuro (clima neon). **Tudo gravado na cena** (aparece no editor).
  - `arena.gd` desenha as linhas do grid (ImmediateMesh, ciano) ao rodar.

### ✅ Bloco 2 — Player e Healer
- **Cena `scenes/characters/player.tscn`** (CharacterBody3D + Malha + Colisao + Nariz),
  com cápsula azul, colisão e materiais **gravados na cena**.
- **`player.gd`**:
  - Movimento **livre** no plano XZ por **WASD** + **analógico esquerdo do gamepad**
    (com deadzone). Vira pra direção do movimento.
  - **Healer** (vida): `HEALER_MAX = 100`, `receber_dano()`, `aplicar_empurrao()`
    (pronto pro knockback da mina), sinais `healer_mudou` / `healer_zerou`.
  - `id_jogador` exportado (= 1).
- A arena instancia o Player no tile de spawn `(3, 8)` e conecta `healer_zerou`
  (fim de partida — placeholder até o HUD/GameManager do bloco 5).

### ✅ Bloco 3 — Armadilha Mina (a única do slice)
- **Base `scenes/characters/combatente.gd`** (`extends CharacterBody3D`, `class_name
  Combatente`): Healer (`receber_dano`/`aplicar_empurrao`), sinais `healer_mudou`/
  `healer_zerou`, registro no grupo `combatentes`. Player e Bot herdam dela (por
  CAMINHO, não por `class_name` — resolve headless sem cache de classe do editor).
- **Cena `scenes/traps/mina.tscn`** (Area3D `Detector` cilindro r=0,7 + `Marca`
  disco neon) + **`mina.gd`**:
  - Estados ARMANDO → ARMADA (0,5s) → EXPLODIDA. Antes de armar é inerte.
  - Dispara no `body_entered` de um corpo com `id_jogador != dono_id` (o dono não
    explode a própria). **Dano 20 + knockback** em todos os combatentes no raio 2,2
    (inclui o dono — GDD). Acoplamento solto: usa `has_method` + grupo `combatentes`.
  - Ao explodir: libera o tile (`GridManager.remover_armadilha`) e emite `consumida`.
  - **Obs.:** GDD lista só "dano" pra Mina; o CLAUDE.md do slice pede dano+knockback
    — seguimos o CLAUDE.md.
- **Plantio no `player.gd`:** botão **Espaço** (teclado) / **A** (gamepad) com borda.
  Inventário **4 minas** (`minas_disponiveis`, sinal `minas_mudou` pra HUD). Snap no
  tile via `GridManager`; não planta em tile ocupado; mina vai pra arena (`get_parent`),
  não fica presa ao player. Recarga: **volta 1 mina 6s** após explodir (`consumida`).

### ✅ Bloco 4 — Bot inimigo
- **Cena `scenes/characters/bot.tscn`** (cápsula vermelha, `id_jogador=2`) + **`bot.gd`**
  (herda `Combatente`): persegue o player em **linha simples** (sem pathfinding/desvio),
  para a 1,2u, pode pisar nas minas. Acha o alvo pelo grupo `combatentes` (id diferente).
- Arena instancia o Bot no tile `(9,3)` ≈ mundo (7,1,-5) e conecta `healer_zerou`.

### ✅ Bloco 5 — Vitória + HUD
- **Autoload `GameManager`** (`autoloads/game_manager.gd`, registrado em `project.godot`):
  relógio de **90s** e regras de vitória — vence quem zerar o Healer do oponente; no
  fim do tempo vence quem tomou menos dano (maior Healer), com empate possível.
  Sinais `tempo_mudou` / `partida_acabou(vencedor_id, motivo)`. Acoplamento solto: a
  arena registra os combatentes em `iniciar_partida([...])`.
- **HUD `scenes/ui/hud.tscn` + `hud.gd`** (CanvasLayer): dois Healers (barra azul do
  jogador, vermelha do bot), **timer** no topo-centro, **contador de minas** no rodapé,
  e label de fim de partida (VOCÊ VENCEU / PERDEU / EMPATE). Só ouve por signal.
- Arena (modo normal) chama `$HUD.configurar(player, bot)` e `GameManager.iniciar_partida`.

### ✅ Verificação (blocos 3 a 5)
- **Teste automatizado headless** em `arena.gd` (`--teste`): planta com snap, valida
  ocupação/inventário/bloqueio de tile duplo, move o bot até a mina (dano + tile
  liberado) e checa a vitória (partida em 90s, jogador vence ao zerar o bot).
  Rodar: `Godot ... --headless ++ --teste`. **8/8 passaram.**
- Screenshot (`--capturar`) confirma a HUD completa + player azul + bot vermelho na
  grade 12×12.

## 🎉 Fase 2 (vertical slice) COMPLETA
Critério de pronto atingido: dá pra jogar uma partida — mover (WASD), plantar minas
(Espaço), o bot persegue e pisa, toma dano/knockback, e há regras de vitória + HUD.
**Próximo: Fase 3** (sistema completo de armadilhas — Detonador, Bomba, Gás, Cova,
Painel de Força + Caution Mode), conforme roadmap do `GDD.md` seção 15.

---

## Como rodar / ver
- Abrir o projeto no Godot 4.6 e apertar **Play (F5)**. A cena principal é
  `scenes/arena/arena.tscn`.
- No editor, a arena e o player já aparecem na viewport; o **grid ciano** e o
  **movimento** só aparecem rodando (Play).
- Controles: **WASD**/analógico esquerdo pra mover, **Espaço**/botão **A** pra plantar mina.

## Notas técnicas (importante pro fluxo com o MCP)
- O desenvolvimento é feito via **Godot MCP** (editor precisa estar aberto).
- Limitações conhecidas do MCP e workarounds estão na memória do agente
  (`execute_editor_script` com sandbox, `update_node_property` não grava
  Vector3/resources, sem tool de rodar/screenshot → captura via linha de comando).
- Visual sempre **gravado no `.tscn`** (não montado por código), pra aparecer no editor.
- `_captura_arena.png` na raiz é um artefato de captura de dev (ignorado no git).
