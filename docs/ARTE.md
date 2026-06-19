# VAULTBREAKER — Guia de Arte (Art Bible)

Direção visual e specs pra trocar os placeholders por arte de verdade. Escrito a partir do
estado real do projeto (câmera, escala, código de cores já usado). Vale pra um artista
humano OU pra uma IA de geração de assets. Idioma do projeto: **português**.

---

## 1. Pilares visuais (não fuja deles)

1. **Neon urbano / cyberpunk corporativo.** Mundo da megacorp **VECTOR**: concreto sujo,
   metal escuro, e **luz neon** como cor (faixas, hologramas, telas, sinais).
2. **Leitura top-down acima de tudo.** A câmera é quase de cima — o que importa é a
   **silhueta vista de cima**, o **contraste de valor** e o **código de cores**. Detalhe
   facial e textura fina quase não aparecem; não gaste budget neles.
3. **O mapa é a arma → o chão fala.** Tiles, armadilhas, Vaults, pontes e perigos têm que
   ser lidos num relance. Clareza > realismo.
4. **Feedback gostoso.** Explosão, queda, knockdown e o flash de armadilha precisam ter
   peso: luz forte, partícula, screenshake (já implementado).

Referências de *mecânica/leitura* pra estudar (NÃO copiar arte/marcas): Trap Gunner (PS1,
a base do design), e o "neon top-down" de jogos como Ruiner / Hyper Light Drifter pra
clareza de cor. Mundo e personagens são **originais**.

---

## 2. A câmera define tudo (specs reais)

- **Câmera ortográfica**, inclinação de **~60°**, `size = 30`, posição `(0, 26, 15)`.
  → vê o **topo e um pouco da frente** dos objetos. Ombros, cabeça, costas e o chão são o
  que aparece. A "cara" do personagem importa pouco.
- **Escala:** 1 unidade = 1 metro. **Tile = 2×2 m.** Arena de 12×12 a 16×10 tiles.
- **Personagem:** cápsula atual r=0.5, h=2.0 → modelo de **~1.8–2.0 m**, cabe num cilindro
  de **raio 0.5 m**. Frente = **−Z**.
- **Implicação prática:** desenhe pensando na **vista de cima**. Faça a silhueta superior
  (capacete, ombreiras, mochila, arma) ser distinta por personagem. Use **cor + forma do
  topo** pra diferenciar, não o rosto.

---

## 3. Código de cores CANÔNICO (já é regra no jogo)

Estas cores estão no **radar/HUD (GDD 11)** e no gameplay. **Respeite-as** — o jogador
aprende a lê-las:

| Cor | Significado |
|-----|-------------|
| **Azul** | Jogador 1 (você) |
| **Vermelho** | Jogador 2 / bot |
| **Verde** | Vault (P.O.D.S.) — pisca quando tem item |
| **Amarelo** | Field Trap **e armadilha detectada** (Caution Mode) |
| **Azul claro** | Ponte / passarela |

Cor de **time** (azul vs. vermelho) deve aparecer no personagem (faixa/emissivo) pra saber
de quem é cada um e cada armadilha. Reserve um **slot de material tingível** no modelo.

---

## 4. Personagens (roster de 6)

Specs técnicas completas em **`docs/CRIACAO_DE_PERSONAGENS.md`** (formato .glb, rig,
animações, poly budget). Aqui vai a **direção de arte** por personagem (personalidade da
seção 4 do GDD) — cada um precisa de silhueta de topo única:

| Personagem | Vibe | Gancho visual (topo) |
|-----------|------|----------------------|
| **BRECHT**, o Demolidor | bombista de área | volumoso, cintos de explosivos, ombreiras |
| **MAGNUS**, o Executor | tanque shotgun | o maior/mais largo, blindado, pesado |
| **VESNA**, a Controladora | nega espaço, rápida | esguia, ágil, drones/antenas |
| **PIP**, a Unidade | droid caótico, lento | robótico, assimétrico, "instável" |
| **KESTREL**, o Corredor | velocíssimo, vida baixa | leve, lâminas, leitura de "veloz" |
| **MARA**, a Aberração | controla o chão, lenta | orgânica/mutante, perfil baixo e largo |

Regras: **paleta própria** por personagem (além da cor de time), **silhueta de topo
distinta** (some 2 deles num minimapa e ainda dá pra distinguir), e **emissivo** marcando
a arma/super.

---

## 5. Armadilhas (as 6) — a regra de ouro da leitura

⚠️ **Regra crítica de gameplay:** armadilha **armada é quase invisível pro inimigo**. Hoje
o marcador é pequeno e translúcido; o **raio/efeito só aparece no disparo** (flash) ou na
nuvem de Gás ativa. **Não faça armadilha plantada chamativa** — isso quebraria o jogo. O
que brilha é o **momento do disparo**.

Cores atuais (do `.tres`, mantenha como base de identidade):

| Armadilha | Cor base | Disparo (o que precisa de punch) |
|-----------|----------|----------------------------------|
| **Mina** | laranja | explosão + knockback |
| **Bomba** | amarelo | explosão grande (combo) |
| **Detonador** | verde | aciona bombas no raio |
| **Gás** | verde-menta | **nuvem** persistente (a única visível por tempo) |
| **Cova** | marrom | buraco que prende (imobiliza) |
| **Painel de Força** | roxo | arremesso direcional (seta de impulso) |

Dois estados por armadilha: **(a) marcador discreto** plantado (o dono vê sutil, o inimigo
quase não) e **(b) FX de disparo** forte. O marcador da fatia no **menu radial** usa a
mesma `cor` — então um ícone limpo por tipo ajuda os dois lugares.

---

## 6. Field traps e perigos de mapa

| Objeto | Hoje | Direção |
|--------|------|---------|
| **Obstacle Box** | caixa cinza | engradado destrutível, "tem item dentro?" |
| **Bomb Box** | caixa avermelhada | engradado com símbolo de perigo/explosivo |
| **Laser/Rocket Launcher** | bloco com emissivo vermelho | torreta de mapa, "boca" que dispara |
| **Esteira** | quadrado ciano | setas de movimento, textura rolando |
| **Ponte/passarela** | quadrado azul claro elevado | estrutura elevada (passa por baixo) |
| **Spark Bit** | esfera amarela elétrica | eletricidade viva, faísca animada |
| **Vault (P.O.D.S.)** | cilindro verde | cápsula/portal que cospe item; pisca com item |

Perigos têm que ler como **"isto te machuca"** num relance (vermelho/amarelo + animação).

---

## 7. Projéteis, super e FX

- **Projétil (tiro):** hoje esfera amarela emissiva. Vire um traço/bala com **trail**.
- **Plasma (Unit/super):** hoje esfera roxa grande. É o momento mais épico do jogo — faça
  **roxo intenso, pulsante, com glow e trail**, claramente "perigo máximo".
- **Explosão:** já tem `CPUParticles` (laranja) + flash + screenshake. Pode evoluir pra
  GPUParticles com fumaça/centelha quando tiver GPU garantida; mantenha o **flash branco-
  quente** no impacto.
- **Nuvem de Gás:** verde translúcida, volumétrica-fake (cartão/partícula). É **persistente**
  — única armadilha visível por tempo.
- **Knockdown/derrubado:** falta FX — adicione "estrelinhas"/poeira e talvez uma pose.

---

## 8. Arena / ambiente

- **Chão:** hoje escuro fosco `(0.1, 0.11, 0.16)`. Mantenha **escuro e dessaturado** pra o
  neon saltar. Pode ter painéis, placas VECTOR, grades, manchas — mas **baixo contraste**
  pra não competir com os elementos de gameplay.
- **Grid:** linhas **ciano neon translúcidas** (já desenhadas por código). É leitura de
  gameplay (tiles), então **mantenha visível mas sutil**.
- **Iluminação:** uma direcional + ambiente baixo; o look vem de **materiais emissivos**
  (`emission` no StandardMaterial3D). Pense "tudo que importa **acende**".
- **Fundo/ambiente:** céu/horizonte escuro corporativo (`WorldEnvironment` já tem um azul
  bem escuro). Skyline neon distante opcional.
- **Bordas da arena:** hoje não há parede; ao adicionar, deixe **baixas** pra não tampar a
  vista top-down.

---

## 9. UI / HUD / menus

- **HUD atual:** barras de Healer (azul/vermelho), timer central, contadores, radar no
  canto. Direção: **HUD diegética-neon**, cantos limpos, tipografia condensada/tech.
- **Tipografia:** uma fonte **sans condensada / techno** (display pro título, legível pro
  HUD). Hoje usa a fonte default — troque por uma com personalidade cyberpunk.
- **Menu radial:** roda com as 6 armadilhas na **cor de cada tipo** + contagem. Ícone limpo
  por armadilha eleva muito.
- **Radar:** mantenha o **código de cores canônico** (seção 3).
- **Telas:** Título → Seleção → Arena, com Pausa e fim/rematch. Dê a elas um **fundo neon**,
  logo do VAULTBREAKER e arte dos personagens na seleção.

---

## 10. Especificação técnica (pipeline)

- **Modelos:** glTF binário **`.glb`** (nativo do Godot 4). Up=Y, **Forward=−Z**, metros,
  pivot nos pés.
- **Poly budget (top-down):** personagens **3k–8k tris** (herói até ~12k); props/armadilhas
  **300–2k**; field traps **500–3k**.
- **Texturas PBR:** atlas 1k–2k, mapas **albedo + normal + ORM + EMISSION**. O **emission
  é essencial** (é o neon). Reserve máscara de **cor de time**.
- **Materiais:** `StandardMaterial3D`/`ORMMaterial3D` com `emission_enabled`. Unshaded só
  pra UI/grid.
- **Animações** (no `.glb`, nomes em PT): `parado, correr, plantar, desarmar, atirar,
  recarregar, atingido, preso, derrubado, ko`. 30 fps, in-place. (Detalhes em
  `docs/CRIACAO_DE_PERSONAGENS.md`.)
- **Áudio:** o `AudioManager` toca `assets/audio/<evento>.wav` se existir (hoje usa beeps
  procedurais). Eventos: `plantar, tiro, explodir, soco, desarme, item, vitoria`.

---

## 11. Por onde começar (prioridade)

A leitura é tudo, então ataque na ordem que mais muda a cara do jogo:

1. **Os 2 personagens jogáveis** (1 com 2 cores de time) — é o que o olho segue.
2. **Ícones das 6 armadilhas** (radial + marcador) — clareza imediata do loop.
3. **Chão + grid + paredes baixas** — define o "lugar".
4. **FX de explosão e da Plasma** — o "feedback gostoso".
5. **Vault, Spark Bit, field traps** — perigos do mapa.
6. **Tipografia + telas de menu** — acabamento.
7. **Resto do roster (4 personagens)** e **áudio real**.

Mantenha a **disciplina de cor** (seção 3) e a **regra de armadilha discreta** (seção 5) —
são as duas coisas que, se quebradas, prejudicam o gameplay, não só o visual.

---

Fontes: `GDD.md` (seções 3, 4, 6, 11, 13), `docs/CRIACAO_DE_PERSONAGENS.md` (specs de
personagem), `PROGRESSO.md` (o que existe). Tudo é placeholder hoje — este guia é o alvo.
