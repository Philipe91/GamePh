# PROGRESSO — VAULTBREAKER

Registro de onde o desenvolvimento parou. Fonte de design: `GDD.md`. Regras de
trabalho: `CLAUDE.md`. Atualize este arquivo ao fim de cada bloco.

**Última atualização:** 2026-06-17

---

## Estado atual: Fase 2 (vertical slice) — blocos 1 a 4 PRONTOS

Loop jogável em construção: dá pra plantar mina, o bot persegue e pisa, toma dano.
Falta o bloco 5 (HUD + regras de vitória/timer) pra fechar a Fase 2.

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

### ✅ Verificação (blocos 3 e 4)
- **Teste automatizado headless** em `arena.gd` (`--teste`): planta, valida ocupação/
  inventário/bloqueio de tile duplo, move o bot até a mina e confere dano + tile
  liberado. Rodar: `Godot ... --headless ++ --teste`. **Todos passaram.**
- Screenshot (`--capturar`) confirma player azul + bot vermelho na grade 12×12.

---

## ⏭️ Próximo: Bloco 5 — Vitória + HUD
Conforme `CLAUDE.md` seção 5 e `GDD.md`:
- **Vitória** por zerar o Healer do oponente em 90s; se o
  tempo acabar, vence quem tomou menos dano. HUD: dois Healers, timer, contador de minas.
- **Critério de pronto da Fase 2:** dá pra ganhar uma partida plantando minas contra
  o bot, e é divertido. Só então seguimos pra Fase 3 (sistema completo de armadilhas).

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
