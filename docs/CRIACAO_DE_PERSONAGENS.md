# VAULTBREAKER — Documento técnico para criação de personagens

> Guia para outra IA (ou artista) criar personagens **compatíveis** com o projeto.
> Estado real em 2026-06-18: o jogo usa **cápsulas placeholder**. Não há modelos 3D,
> skins nem animações ainda. Este documento define o **contrato de integração** que já
> existe no código e a **especificação de assets** recomendada para quando entrarem.

---

## 0. Visão geral técnica

- **Engine:** Godot **4.6.3** stable (standard, não-.NET). `config/features = "4.6", "Forward Plus"`.
- **Linguagem:** GDScript **tipado**. Todo código e comentário em **português**.
- **Render:** Forward+ (desktop primeiro). Estilo **2.5D**: modelos 3D vistos por câmera
  **ortográfica top-down** com inclinação de ~60°. Estética **neon urbano / cyberpunk**.
- **Câmera (arena.tscn):** `Camera3D` ortográfica (`projection = 1`), `size = 30`,
  inclinação de 60° (basis = rotação de 60° em X), posicionada em ~`(0, 26, 15)`.
  → O personagem é visto **de cima e um pouco de frente**. O rosto/frente importa pouco;
  silhueta, topo e ombros importam muito.
- **Escala do mundo:** 1 unidade = 1 metro. Tile do grid = **2×2 m**. Arena 12×12 tiles.

---

## 1. Contrato de integração (o que o código JÁ espera)

Todo personagem herda de **`scenes/characters/combatente.gd`** (`class_name Combatente`,
`extends CharacterBody3D`). Player e Bot herdam **por CAMINHO**
(`extends "res://scenes/characters/combatente.gd"`), não por `class_name` — isso resolve
em headless sem o cache de classe do editor. **Mantenha esse padrão.**

### 1.1 Raiz da cena
- Tipo do nó raiz: **`CharacterBody3D`**.
- Script: estende `combatente.gd` (direto ou uma futura base `personagem.gd`).
- Export `id_jogador: int` — **1 = jogador, 2 = oponente**. A identidade de time decide
  quem dispara armadilha de quem (a Mina inimiga explode; a própria, não).

### 1.2 O que o Combatente fornece (não reimplemente)
- **Healer** (vida): `HEALER_MAX = 100.0`, var `healer`. Métodos: `receber_dano(qtd)`,
  `curar(qtd)`, `aplicar_empurrao(direcao, forca)`.
- **Efeitos de status:** `imobilizar(s)`, `aplicar_slow(fator, s)`, `fator_velocidade()`,
  `esta_imobilizado()`, `tentar_escapar(qtd)` (button-mash p/ sair da Cova).
- **Sinais:** `healer_mudou(atual, maximo)`, `healer_zerou`.
- **Grupo:** entra em `"combatentes"` no `_ready()`. Armadilhas acham alvos por esse grupo
  via `has_method("receber_dano")` — **acoplamento solto, nunca por nome de nó**.
- **Posição de piso:** `ALTURA_PISO = 1.0`. O centro da cápsula fica em `y = 1.0` para os
  **pés tocarem o chão em y = 0**. Subclasses fixam `position.y = ALTURA_PISO` no movimento.

### 1.3 Convenção de orientação (movimento)
- **Frente do personagem = `-Z`** (eixo Z negativo). O player/bot giram com
  `rotation.y = atan2(-velocity.x, -velocity.z)`.
- O modelo importado **deve olhar para -Z** na pose de descanso. Se vier olhando para +Z,
  rotacione 180° no nó do modelo (não no raiz).
- Movimento é **livre** no plano XZ (`move_and_slide`), nunca travado em célula. O snap
  para tile só acontece ao **plantar armadilha** (responsabilidade do `GridManager`).

### 1.4 Estrutura de nós atual (placeholder a substituir)
```
player (CharacterBody3D)         # raiz, script player.gd
├─ Malha (MeshInstance3D)        # CapsuleMesh r=0.5 h=2.0  ← TROCAR pelo modelo glTF
│  └─ Nariz (MeshInstance3D)     # BoxMesh, marca a frente   ← remover quando houver modelo
└─ Colisao (CollisionShape3D)    # CapsuleShape3D r=0.5 h=2.0 ← MANTER (colisão do jogo)
```
Ao trocar pelo modelo real, **preserve o `CollisionShape3D` cápsula** (gameplay depende
da forma) e substitua o nó `Malha` pela cena importada do `.glb` (que traz `Skeleton3D` +
`AnimationPlayer`).

---

## 2. Especificação dos assets 3D (recomendada — ainda não há assets)

### 2.1 Formato
- **glTF binário `.glb`** — formato nativo recomendado pelo Godot 4. Um arquivo por
  personagem, com malha + esqueleto + animações embutidos. (FBX exige plugin e não é o
  padrão; OBJ não carrega rig/anim. Use `.glb`.)
- Eixo **Up = Y**, **Forward = -Z**, unidades em **metros**.
- **Origem (pivot) nos pés**, em `(0, 0, 0)`, centrado em XZ.

### 2.2 Dimensões
- Altura ~**1.8–2.0 m** (casar com a cápsula de 2.0 m de altura / raio 0.5 m).
- Caber dentro de um cilindro de **raio 0.5 m** (a colisão é essa cápsula).

### 2.3 Orçamento de polígonos (alvo p/ 2.5D top-down)
- **3.000–8.000 triângulos** por personagem é o ideal (câmera distante, silhueta manda).
- Teto de **~12.000 tris** para um "herói". Evite detalhe facial caro — quase não aparece.
- **1 malha skinada** por personagem de preferência (menos draw calls).

### 2.4 Texturas / material (PBR, look neon)
- Atlas **1024² ou 2048²**. Mapas: **albedo**, **normal**, **ORM** (Occlusion/Roughness/
  Metallic), e **emission** (essencial para o neon — partes que "acendem").
- `StandardMaterial3D` ou `ORMMaterial3D`. Use **emission** para faixas/luzes do traje.
- Cor de time: reserve uma máscara ou material trocável para tingir **azul (time 1)** e
  **vermelho (time 2)** — ver seção 4 (skins).

### 2.5 Esqueleto / rig
- Rig **humanoide** simples, importado como `Skeleton3D`. **< 60 ossos.**
- Pesos suaves (máx 4 influências por vértice). Sem morph targets obrigatórios.

---

## 3. Animações (recomendado — ainda não há `AnimationPlayer` no projeto)

O modelo `.glb` deve trazer um **`AnimationPlayer`** com clipes nomeados em **português**.
Conjunto mínimo para o gameplay atual e o planejado (Fases 3–4):

| Clipe        | Loop | Quando toca                                   |
|--------------|------|-----------------------------------------------|
| `parado`     | sim  | idle, sem input                               |
| `correr`     | sim  | movimento (velocidade > 0)                    |
| `plantar`    | não  | ao plantar armadilha (Espaço/A)               |
| `desarmar`   | sim  | durante o Disarming Code (player parado)      |
| `atirar`     | não  | disparo de projétil (Fase 4)                  |
| `recarregar` | não  | recarga da arma (Fase 4)                      |
| `atingido`   | não  | ao tomar dano (`receber_dano`)                |
| `preso`      | sim  | imobilizado por Cova/Gás (`esta_imobilizado`) |
| `derrubado`  | não  | knockdown / arremesso do Painel               |
| `ko`         | não  | Healer zerou (`healer_zerou`)                 |

- Frame rate **30 fps**, raiz **in-place** (sem root motion — o código move o corpo).
- Nomes exatamente como acima (a integração futura vai chamar por string).

---

## 4. Sistema de skins (NÃO existe — especificação proposta)

Hoje "skin" = apenas troca de **cor do material** da cápsula (azul = player, vermelho =
bot), via `material_override`. Não há sistema de skins, nem troca em runtime.

Proposta compatível para quando entrar:
- Cada personagem tem 1 malha base; a **cor de time** é aplicada por um slot de material
  trocável ou por `material_override` numa máscara. Skins alternativas = conjuntos de
  textura (albedo/emission) trocados em runtime, mesmo esqueleto e malha.
- Guardar skins como `resources/skins/<personagem>/<skin>.tres` (futuro `StatsSkin`/
  material set). **Não** duplicar a malha por skin.

---

## 5. Sistema de personagens (parcial — base existe, roster NÃO)

- **Existe:** a base `Combatente` e duas variações concretas (`player.gd`, `bot.gd`).
- **NÃO existe:** roster jogável, seleção de personagem, nem `StatsPersonagem` (.tres).
  Está planejado para a **Fase 5** do roadmap (GDD seção 15).
- O GDD (seção 4) define **6 personagens**: BRECHT, MAGNUS, VESNA, PIP, KESTREL, MARA —
  cada um com **arma à distância**, **loadout de 3 tipos de armadilha** com quantidades
  fixas, **velocidade** e **vida** próprias.

### 5.1 `StatsPersonagem` (.tres) — schema PROPOSTO (a implementar)
Espelhar o padrão de `StatsArmadilha` (Resource exportado, balanceável sem código):
```gdscript
extends Resource
class_name StatsPersonagem

@export var nome: String                  # "BRECHT"
@export var cor_time: Color               # cor base / tinta de time
@export var vida_max: float = 100.0       # Healer inicial
@export var velocidade: float = 7.0       # m/s (player atual = 7.0; bot = 5.0)
@export var arma: String                  # "pistola" | "shotgun" | "missil" | ...
@export var loadout: Dictionary = {}      # { "mina": 4, "bomba": 4, "detonador": 1 }
@export var cena_modelo: PackedScene      # .glb importado do personagem
```
Loadouts da seção 4 do GDD (ponto de partida):
- BRECHT: Detonador 1, Bomba 4, Mina 4 — velocidade média.
- MAGNUS: Detonador 2, Bomba 6, Gás 2 — lento, vida alta.
- VESNA: Mina 5, Gás 1, Painel 3 — rápido.
- PIP: Detonador 3, Cova 4, Painel 4 — lento.
- KESTREL: Mina 2, Cova 3, Painel 2 — muito rápido, vida baixa.
- MARA: Mina 3, Cova 6, Gás 2 — lento, controle de chão.

---

## 6. Convenções de nomes (observadas no projeto)

| Item                     | Convenção                          | Exemplos                                   |
|--------------------------|------------------------------------|--------------------------------------------|
| Arquivos `.gd` / `.tscn` | `snake_case` / minúsculo           | `grid_manager.gd`, `player.tscn`, `mina.tres` |
| `class_name`             | `PascalCase`                       | `Combatente`, `StatsArmadilha`             |
| Autoloads (singletons)   | `PascalCase`                       | `GridManager`, `GameManager`               |
| Nós dentro da cena       | `PascalCase` em português          | `Malha`, `Colisao`, `OverlayCaution`       |
| Funções e variáveis      | `snake_case` em português          | `receber_dano`, `tempo_restante`           |
| Constantes               | `UPPER_SNAKE_CASE`                 | `HEALER_MAX`, `ALTURA_PISO`, `VELOCIDADE`  |
| Sinais                   | `snake_case`, fato consumado       | `healer_mudou`, `armadilha_plantada`       |
| Grupos                   | minúsculo, plural                  | `"combatentes"`, `"armadilhas"`            |
| Idioma                   | **português** em TODO código/comentário/asset | —                              |

---

## 7. Organização de pastas (real)

```
res://
  autoloads/          # GridManager, GameManager (singletons de estado global)
  scenes/
    arena/            # arena.tscn (+ arena.gd): câmera, luz, chão, grid, regras
    characters/       # combatente.gd (base) + player/bot (.tscn + .gd)
    traps/            # armadilha.tscn + armadilha.gd (genérica, ramifica por tipo)
    items/            # itens da Vault (vazio — Fase 4)
    ui/               # hud.tscn + hud.gd
  scripts/            # classes base soltas (stats_armadilha.gd)
  resources/
    armadilhas/       # .tres de cada armadilha (mina, bomba, detonador, gas, cova, painel)
  assets/
    models/           # modelos 3D .glb        ← VAZIO (.gdkeep)
    sprites/          # texturas e ícones      ← VAZIO (.gdkeep)
    audio/            # sfx e música           ← VAZIO (.gdkeep)
  docs/               # este documento
```
**Sugestão para personagens:** `assets/models/personagens/<nome>/<nome>.glb`,
`scenes/characters/<nome>.tscn`, `resources/personagens/<nome>.tres`.

---

## 8. Como adicionar um novo personagem (passo a passo)

> Hoje funciona para a **forma/visual**; a seleção de roster e o `StatsPersonagem` ainda
> serão criados na Fase 5. Já deixe os assets prontos neste contrato.

1. **Importar o modelo:** colocar `<nome>.glb` em `assets/models/personagens/<nome>/`.
   Conferir: olha para **-Z**, ~2 m de altura, pivot nos pés, `AnimationPlayer` com os
   clipes da seção 3.
2. **Criar a cena** `scenes/characters/<nome>.tscn`:
   - Raiz `CharacterBody3D` com script que **estende `combatente.gd`** (por caminho).
   - Filho = instância do `.glb` (substitui o nó `Malha`); garantir que o modelo aponta -Z.
   - Manter `CollisionShape3D` com `CapsuleShape3D` (raio 0.5, altura 2.0).
   - Definir `id_jogador` conforme o time.
3. **Stats:** criar `resources/personagens/<nome>.tres` (`StatsPersonagem`, schema da
   seção 5.1) com vida, velocidade, arma e loadout da seção 4 do GDD.
4. **Animação:** ligar os estados de gameplay aos clipes (parado/correr/plantar/desarmar/
   atingido/preso/ko) — preferir um nó/script que ouça os sinais do `Combatente`.
5. **Validar headless** (sem abrir janela): rodar a suíte
   `godot --headless --path "<proj>" -- --teste` e conferir que nada quebrou. Para ver o
   visual, usar um modo de captura (`--demo*`) que salva PNG e fecha sozinho — **nunca**
   rodar o Godot de forma bloqueante.

---

## 9. Checklist de compatibilidade (resumo p/ a IA de assets)

- [ ] `.glb` único, Up=Y, **Forward=-Z**, metros, pivot nos pés, ~2 m de altura.
- [ ] Cabe no cilindro raio 0.5 m. 3k–8k tris (máx ~12k). 1 malha skinada.
- [ ] PBR 1k–2k: albedo, normal, ORM, **emission** (neon). Máscara de cor de time.
- [ ] Esqueleto humanoide < 60 ossos, in-place (sem root motion).
- [ ] `AnimationPlayer` com clipes **em português**: `parado, correr, plantar, desarmar,
      atirar, recarregar, atingido, preso, derrubado, ko` (loop onde indicado).
- [ ] Nomes de nós/arquivos seguem a seção 6. Tudo em **português**.
- [ ] Não depende de nome de nó externo; integra via `Combatente` (grupo "combatentes",
      `receber_dano`, sinais).

> Fonte de verdade de design: `GDD.md` (seções 4, 6, 14, 15). Regras de trabalho:
> `CLAUDE.md`. Estado de desenvolvimento: `PROGRESSO.md`.
