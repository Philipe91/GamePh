# VAULTBREAKER — Criação de TODOS os assets (personagens, cenário, armadilhas, tiros, FX)

Documento mestre pra produzir cada asset visual do jogo. Cada item traz: **o que é**,
**escala exata** (tirada do código — 1 unidade = 1 metro, tile = 2 m), **cor (hex)**,
um **prompt de geração** pronto, e **onde plugar**. Câmera do jogo: ortográfica top-down
~60° → tudo precisa **ler de cima**.

Regra de paleta geral: **fundo/chão escuros e dessaturados; tudo de gameplay ACENDE**
(materiais com `emission`). Look: megacorp **VECTOR**, cyberpunk neon. Formato 3D: **`.glb`**
(Up=Y, Forward=−Z, pivot na base, metros). Não-fotorrealista, game-asset PBR, clean topology.

---

## 0. Preâmbulo de estilo (cole junto de QUALQUER prompt 3D)
> Style: original cyberpunk arena game asset, stylized PBR, clean topology, low-to-mid poly,
> dark neutral base with glowing neon emissive accents, strong readable silhouette from a
> top-down ~60° camera, plain background, not photorealistic. Megacorp "VECTOR" dystopian tech.

---

## 1. PERSONAGENS (6)

- **Escala:** ~**2 m** de altura, cabe num cilindro de **raio 0.5 m**. Frente **−Z**, pivot
  nos pés. (Hoje é uma cápsula r0.5×h2.0.)
- **Cor:** corpo **cinza-metal neutro**; acento neon na cor de cada um (a cor de **time**
  azul/vermelho é aplicada por cima no jogo, então deixe faixas emissivas separadas).
- **Anims** (no `.glb`, nomes em PT): `parado, correr, plantar, desarmar, atirar,
  recarregar, atingido, preso, derrubado, ko`. 30 fps, in-place.
- **Plugar:** `assets/models/personagens/<nome>/<nome>.glb`; ligar no `StatsPersonagem`
  (`resources/personagens/<nome>.tres`); trocar o nó `Malha`. Contrato:
  `docs/CRIACAO_DE_PERSONAGENS.md`.

**Prompts (gere em T-pose):**
- **BRECHT** (#FF8C1A): heavy demolitions bruiser, bulky armor, bandoliers of explosives, chunky pauldrons, stubby automatic pistol.
- **MAGNUS** (#FF4D40): hulking tank, largest/widest, riot-armor plating, big shotgun, immovable.
- **VESNA** (#66FF80): agile zone-control, slim sleek bodysuit, shoulder drones/antennae, dual handguns.
- **PIP** (#994DFF): unstable droid, asymmetric chassis, exposed servos/cables, shoulder homing-missile launcher, glitchy.
- **KESTREL** (#33E6FF): hyper-fast runner, lean lightweight, throwing blades, glass-cannon, reads as speed.
- **MARA** (#CC66E6): mutant ground-control, low/wide hunched organic-meets-machine, biotech growths, regenerating rocket-fist.
- **Negative:** photorealistic, realistic skin, untextured, multiple characters, floating weapons, text, watermark, extra limbs, blurry.

---

## 2. CENÁRIO / ARENA

A arena visual fica gravada em `scenes/arena/arena.tscn`. Hoje: chão plano escuro + grid
ciano por código + ambiente azul-escuro. Substitua/enriqueça mantendo a leitura top-down.

### 2.1 Chão (piso da arena)
- **Escala:** plano de **24×24 m** (cobre o grid 12×12 de tiles de 2 m). Mapas maiores
  (até 16×14) → ajuste.
- **Cor:** base **#1A1C29** (escuro fosco, dessaturado). **Baixo contraste** pra não
  competir com gameplay.
- **Prompt (textura PBR tileável, top-down):** *dark industrial metal/concrete floor,
  seamless tileable PBR texture, subtle panel seams and grime, very dark desaturated
  blue-gray (#1A1C29), faint cyan emissive trim lines, top-down readable, low contrast.*
- **Plugar:** material do nó `Chao` em `arena.tscn` (hoje `StandardMaterial3D` simples).

### 2.2 Grid (linhas dos tiles)
- É **leitura de gameplay** (mostra os tiles de 2 m). Linhas **ciano neon translúcidas
  #00D9FF**. Já desenhado por código (`arena.gd::_desenhar_grid`) — **manter sutil**.

### 2.3 Paredes / borda
- **Escala:** borda baixa (~0.5–1 m de altura) ao redor da arena — **baixa** pra não tampar
  a vista top-down.
- **Prompt:** *low cyberpunk arena perimeter wall segment, dark metal with thin neon strip,
  modular, ~1m tall, top-down friendly.*

### 2.4 Fundo / skybox
- **Cor:** **#080A12** (quase preto azulado). Opcional: skyline neon distante, hologramas
  VECTOR, chuva.
- **Prompt (imagem de fundo/skybox):** *distant dystopian neon cityscape at night, dark
  #080A12 sky, faint magenta/cyan signage, corporate megastructures, atmospheric, blurred
  background.*
- **Plugar:** `WorldEnvironment` em `arena.tscn` (hoje cor sólida).

### 2.5 Luz
- Uma direcional + ambiente baixo (**#404761**). O look vem do **emissivo** dos objetos —
  "tudo que importa acende". Não precisa de muita luz realista.

---

## 3. ARMADILHAS (as 6) — props + ícone + FX

⚠️ **Regra de ouro:** armadilha **plantada é quase invisível pro inimigo** — marcador
pequeno/translúcido. O que brilha é o **disparo** (flash/explosão). Não faça a armadilha
plantada chamativa. Cada uma precisa de: **(a) ícone** (menu radial), **(b) marcador
discreto** no chão, **(c) FX de disparo**.

- **Escala dos props:** cabem num tile de **2×2 m**, discretos (≤ ~0.6 m de "altura" visual).
- **Plugar:** o nó `Marca` da `armadilha.tscn` (hoje um mesh pintado com a cor do tipo);
  a `cor` está em cada `resources/armadilhas/<tipo>.tres`. Ícones entram na HUD/radial.

| Armadilha | Cor (hex) | O prop / disparo |
|-----------|-----------|------------------|
| **Mina** | #FF8C1A | disco baixo no chão; flash + onda de choque ao explodir |
| **Bomba** | #FFD933 | carga explosiva maior; explosão grande (combo) |
| **Detonador** | #33FF80 | pequeno transmissor/antena; aciona bombas no raio |
| **Gás** | #66FF80 | emissor/válvula; **nuvem verde persistente** (a única visível por tempo) |
| **Cova** | #8C6647 | placa de alçapão; vira **buraco** que prende ao disparar |
| **Painel de Força** | #994DFF | placa de impulso; **seta/onda** que arremessa na direção |

**Prompts (props 3D, top-down, ≤0.6m, emissivo na cor do tipo):**
- Mina: *small flat floor proximity mine disc, dark metal, thin orange (#FF8C1A) emissive ring, top-down.*
- Bomba: *compact planted explosive charge, dark casing, yellow (#FFD933) emissive markings, top-down.*
- Detonador: *small remote detonator/antenna device on the ground, green (#33FF80) emissive light, top-down.*
- Gás: *low gas emitter valve/canister, mint-green (#66FF80) emissive vents, top-down.*
- Cova: *floor trapdoor plate, worn metal, brown (#8C6647) tones, top-down (closed state).*
- Painel de Força: *floor force/launch pad plate, purple (#994DFF) emissive arrows, top-down.*

**Ícones (imagem 2D pro menu radial):** *minimal flat neon icon of a [mina/bomba/...],
single color [hex], dark transparent background, clean, readable at small size, UI game icon.*

---

## 4. PROJÉTEIS E SUPER ("tiros")

### 4.1 Tiro (projétil da arma)
- **Escala:** pequeno, ~**0.15–0.3 m** (hoje esfera r0.15). Voa reto.
- **Cor:** **#FFE659** (amarelo quente), emissivo, com **trail/rastro**.
- **Prompt:** *small glowing energy bolt/bullet tracer, bright yellow (#FFE659) emissive
  core with motion trail, game projectile, dark background.*
- **Plugar:** `scenes/projeteis/projetil.tscn` (nó `Malha`).

### 4.2 Plasma (Unit — a super)
- **Escala:** maior, ~**0.4–0.8 m** (hoje esfera r0.4). Teleguiada, lenta, épica.
- **Cor:** **#994DFF** (roxo intenso), **pulsante, glow forte, trail roxo**. É o momento de
  maior perigo do jogo — exagere o brilho.
- **Prompt:** *menacing slow homing plasma orb, intense pulsing purple (#994DFF) energy,
  heavy glow and trailing wisps, electric arcs, ultimate weapon, dark background.*
- **Plugar:** `scenes/projeteis/plasma.tscn` (nó `Malha`).

---

## 5. ITENS, VAULT E SPARK BIT

### 5.1 Vault (P.O.D.S.)
- **Escala:** ~**1.4 m** de largura, baixa (hoje cilindro top_radius 0.7, h 0.3). Fica num
  tile; **pisca verde quando tem item**.
- **Cor:** **#33FF66** (verde). Cápsula/portal/dispensador que cospe item.
- **Prompt:** *futuristic floor dispenser pod (P.O.D.S.), hexagonal, green (#33FF66)
  emissive core, opens to release items, top-down.*
- **Plugar:** `scenes/items/vault.tscn` (nó `Marca`).

### 5.2 Itens (drops da Vault)
- **Escala:** ~**0.6 m** (hoje box 0.6). Flutuam/giram. Tipos e cor sugerida:
  - Speed Up → ciano · Protect → escudo azul · Healer → cruz verde · Unit → roxo (#994DFF)
  · Item de Armadilha → cor da armadilha.
- **Prompt:** *small floating glowing pickup item, neon [cor] emissive, simple iconic shape
  ([raio/escudo/cruz/orbe]), rotating game powerup, dark background.*
- **Plugar:** `scenes/items/item.tscn` (nó `Malha`); o `tipo` define o efeito.

### 5.3 Spark Bit (perigo aos 30s)
- **Escala:** ~**1.1 m** (hoje esfera r0.55). Eletricidade viva, dá dano ao toque.
- **Cor:** **#FFFF4D** (amarelo elétrico), com **faíscas/arcos animados**.
- **Prompt:** *living ball of crackling electricity, bright yellow (#FFFF4D) emissive,
  arcing sparks, dangerous hazard orb, animated energy, dark background.*
- **Plugar:** `scenes/items/spark_bit.tscn` (nó `Malha`).

---

## 6. FIELD TRAPS (perigos de mapa)

Devem ler como **"isto te machuca / interage"** num relance. Destrutíveis por tiro/bomba.

- **Obstacle Box** — ~**1.4 m** (box 1.4). Engradado destrutível, "tem item dentro?".
  *industrial destructible crate, dark metal, faint neon edges, top-down.*
- **Bomb Box** — mesma escala, **símbolo de perigo/explosivo vermelho**. Explode ao quebrar.
  *destructible explosive crate, red hazard markings, danger symbol, top-down.*
- **Laser/Rocket Launcher** — ~**0.9×1.3×0.9 m** (box). Torreta de mapa com "boca" que
  dispara. *wall/floor turret launcher, dark metal, red (#FF…) emissive aperture, top-down.*
- **Esteira (Conveyer Belt)** — **2×2 m** (1 tile). Setas de movimento, textura rolando.
  Cor **#4D80B3**. *conveyor belt floor tile, moving arrow stripes, blue (#4D80B3) emissive,
  top-down, seamless.*
- **Ponte / passarela** — **2×2 m**, **elevada** (~2 m acima). Cor **azul claro #80CCFF**.
  Passa-se por baixo (evasão da Plasma). *elevated walkway/bridge segment, light-blue
  (#80CCFF) emissive trim, dark metal, top-down.*
- **Plugar:** `scenes/field_traps/{caixa,lancador,esteira,ponte}.tscn`.

---

## 7. FX (explosão, gás, knockdown) — partícula ou sprite

Hoje há `CPUParticles` na explosão (laranja) + flash + screenshake. Pode evoluir:

- **Explosão:** flash **branco-quente** no impacto + partículas **#FFB333** (laranja) +
  fumaça curta. Sprite sheet OU partículas. *stylized explosion burst, white-hot flash,
  orange (#FFB333) embers and smoke, short, game VFX.*
- **Nuvem de Gás:** verde translúcida **#66FF80**, **persistente** (única visível por tempo).
  *toxic gas cloud, translucent mint-green (#66FF80), volumetric-ish, lingering, game VFX.*
- **Knockdown/derrubado:** poeira + "estrelinhas" no impacto. *small dust + stun stars hit
  effect, game VFX.*
- **Muzzle/trail dos tiros e Plasma:** ver seção 4.
- **Plugar:** `scenes/arena/explosao_fx.tscn` (já existe) e novos FX no spawn de cada evento.
  Áudio dos eventos: `assets/audio/<evento>.wav` (`AudioManager` usa automático).

---

## 8. UI / TIPOGRAFIA / RADAR

- **Fonte:** trocar a default por uma **sans condensada/techno** (cyberpunk). Uma display
  pro título, uma legível pro HUD.
- **Radar (cores canônicas — NÃO mude):** P1 #4DB3FF · P2 #FF5966 · Vault #33FF66 ·
  Field trap/detectada #FFD91A · Ponte #80CCFF.
- **Telas (título/seleção/pausa/fim):** fundo neon, logo do VAULTBREAKER, arte dos
  personagens na seleção. Estilo HUD diegética-neon, cantos limpos.
- **Plugar:** `scenes/ui/` (titulo, selecao, hud, radial_menu, radar, pausa).

---

## 9. Prioridade de produção

1. **2 personagens** (testar pipeline ponta a ponta) → me mandar os `.glb`.
2. **Ícones das 6 armadilhas** (clareza do loop).
3. **Chão + grid + paredes baixas + skybox** (define o "lugar").
4. **FX de explosão e Plasma** + **tiro** (o "feedback gostoso").
5. **Vault, Spark Bit, field traps**.
6. **Tipografia + telas de menu**.
7. **Resto do roster** + **áudio real** (`.wav`).

---

## 10. Resumo da paleta (hex) — fonte da verdade

- **Time/UI:** P1 #3399FF (radar #4DB3FF) · P2 #FF404D (radar #FF5966) · Vault #33FF66 ·
  Field trap/detectada #FFD91A · Ponte #80CCFF
- **Armadilhas:** Mina #FF8C1A · Bomba #FFD933 · Detonador #33FF80 · Gás #66FF80 ·
  Cova #8C6647 · Painel #994DFF
- **Personagens (acento):** BRECHT #FF8C1A · MAGNUS #FF4D40 · VESNA #66FF80 · PIP #994DFF ·
  KESTREL #33E6FF · MARA #CC66E6
- **Ambiente:** Chão #1A1C29 · Grid #00D9FF · Fundo #080A12 · Luz amb. #404761 · Esteira #4D80B3
- **FX/projéteis:** Tiro #FFE659 · Plasma #994DFF · Explosão #FFB333 (+flash branco) ·
  Spark Bit #FFFF4D

---

Docs relacionados: `docs/ARTE.md` (direção visual), `docs/CRIACAO_DE_PERSONAGENS.md`
(contrato técnico de personagem), `docs/HANDOFF.md` (retomar o projeto), `GDD.md` (design).
Tudo é placeholder hoje — este documento é o alvo. Ao gerar os assets, me mande que eu
integro (trocar malhas, ligar anims, aplicar áudio).
