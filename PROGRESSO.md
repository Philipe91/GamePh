# PROGRESSO — VAULTBREAKER

Registro de onde o desenvolvimento parou. Fonte de design: `GDD.md`. Regras de
trabalho: `CLAUDE.md`. Atualize este arquivo ao fim de cada bloco.

**Última atualização:** 2026-06-17

---

## Estado atual: Fase 2 (vertical slice) — blocos 1 e 2 PRONTOS

O loop ainda não está jogável; estamos construindo a fundação, uma fatia por vez.

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

---

## ⏭️ Próximo: Bloco 3 — Armadilha Mina (a única do slice)
Conforme `CLAUDE.md` seção 5 e `GDD.md` seção 6:
- Botão de plantar faz **snap no centro do tile mais próximo** (usar `GridManager`).
- **Não planta** em tile já ocupado (`pode_plantar`).
- **Arma após 0,5s**, fica **invisível** pro inimigo.
- **Explode** quando o inimigo entra no tile: **dano + knockback**.
- **Inventário de 4 minas**; após explodir, **volta ao inventário em 6s**.
- Boa prática: a Mina **não** deve referenciar o Player diretamente — detectar alvo
  por grupo/Area3D e chamar `receber_dano()` via `has_method` (acoplamento solto).

## Depois (resto da Fase 2)
- **Bloco 4 — Bot inimigo:** CharacterBody3D que persegue o player em linha simples,
  pode pisar nas minas. Sem IA de armadilha ainda.
- **Bloco 5 — Vitória + HUD:** vitória por zerar o Healer do oponente em 90s; se o
  tempo acabar, vence quem tomou menos dano. HUD: dois Healers, timer, contador de minas.
- **Critério de pronto da Fase 2:** dá pra ganhar uma partida plantando minas contra
  o bot, e é divertido. Só então seguimos pra Fase 3 (sistema completo de armadilhas).

---

## Como rodar / ver
- Abrir o projeto no Godot 4.6 e apertar **Play (F5)**. A cena principal é
  `scenes/arena/arena.tscn`.
- No editor, a arena e o player já aparecem na viewport; o **grid ciano** e o
  **movimento** só aparecem rodando (Play).
- Controles: **WASD** ou **analógico esquerdo** do gamepad.

## Notas técnicas (importante pro fluxo com o MCP)
- O desenvolvimento é feito via **Godot MCP** (editor precisa estar aberto).
- Limitações conhecidas do MCP e workarounds estão na memória do agente
  (`execute_editor_script` com sandbox, `update_node_property` não grava
  Vector3/resources, sem tool de rodar/screenshot → captura via linha de comando).
- Visual sempre **gravado no `.tscn`** (não montado por código), pra aparecer no editor.
- `_captura_arena.png` na raiz é um artefato de captura de dev (ignorado no git).
