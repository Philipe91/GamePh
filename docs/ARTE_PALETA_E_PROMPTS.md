# VAULTBREAKER — Paleta (hex) + Prompts de geração 3D

Complemento de `docs/ARTE.md`. **Parte A:** cores exatas extraídas do código (use-as como
fonte da verdade). **Parte B:** prompts prontos pra IA de geração 3D (Meshy, Tripo, Rodin,
etc.) pra criar os 6 personagens.

> Conversão: o Godot usa `Color(r, g, b)` com r/g/b de **0 a 1**. Hex = cada canal ×255.
> Ex.: `Color(0.2, 0.6, 1)` → `#3399FF`.

---

## PARTE A — Paleta exata (hex)

### A.1 Time / UI / Radar (CANÔNICO — não mude)
| Uso | Godot | Hex |
|-----|-------|-----|
| Jogador 1 (corpo) | `Color(0.2,0.6,1)` | **#3399FF** |
| Jogador 2 / bot (corpo) | `Color(1,0.25,0.3)` | **#FF404D** |
| Jogador 1 (radar/HUD) | `Color(0.3,0.7,1)` | **#4DB3FF** |
| Jogador 2 (radar/HUD) | `Color(1,0.35,0.4)` | **#FF5966** |
| Vault (verde) | `Color(0.2,1,0.4)` | **#33FF66** |
| Field trap / detectada (amarelo) | `Color(1,0.85,0.1)` | **#FFD91A** |
| Ponte / passarela (azul claro) | `Color(0.5,0.8,1)` | **#80CCFF** |

### A.2 Armadilhas (identidade de cada uma — base p/ ícone, marcador e flash)
| Armadilha | Godot | Hex |
|-----------|-------|-----|
| Mina | `Color(1,0.55,0.1)` | **#FF8C1A** (laranja) |
| Bomba | `Color(1,0.85,0.2)` | **#FFD933** (amarelo) |
| Detonador | `Color(0.2,1,0.5)` | **#33FF80** (verde) |
| Gás | `Color(0.4,1,0.5)` | **#66FF80** (verde-menta) |
| Cova | `Color(0.55,0.4,0.28)` | **#8C6647** (marrom) |
| Painel de Força | `Color(0.6,0.3,1)` | **#994DFF** (roxo) |

### A.3 Cor de time de cada personagem (acento emissivo do modelo)
| Personagem | Godot | Hex |
|-----------|-------|-----|
| BRECHT | `Color(1,0.55,0.1)` | **#FF8C1A** |
| MAGNUS | `Color(1,0.3,0.25)` | **#FF4D40** |
| VESNA | `Color(0.4,1,0.5)` | **#66FF80** |
| PIP | `Color(0.6,0.3,1)` | **#994DFF** |
| KESTREL | `Color(0.2,0.9,1)` | **#33E6FF** |
| MARA | `Color(0.8,0.4,0.9)` | **#CC66E6** |

> Obs.: a cor acima é a "identidade" do personagem. A cor de **time** (azul P1 / vermelho
> P2) é aplicada por cima via material tingível — então modele o corpo em tom **neutro**
> (cinza-metal) e deixe as faixas emissivas no slot tingível.

### A.4 Ambiente e FX
| Uso | Godot | Hex |
|-----|-------|-----|
| Chão | `Color(0.1,0.11,0.16)` | **#1A1C29** |
| Grid (linhas) | `Color(0,0.85,1)` | **#00D9FF** (ciano neon) |
| Fundo / céu | `Color(0.03,0.04,0.07)` | **#080A12** |
| Luz ambiente | `Color(0.25,0.28,0.38)` | **#404761** |
| Projétil (tiro) | `Color(1,0.9,0.35)` | **#FFE659** |
| Plasma (super) | `Color(0.6,0.3,1)` | **#994DFF** (com glow) |
| Explosão (partícula) | `Color(1,0.7,0.2)` | **#FFB333** + flash branco |
| Spark Bit | `Color(1,1,0.3)` | **#FFFF4D** |
| Esteira | `Color(0.3,0.5,0.7)` | **#4D80B3** |

**Regra de paleta:** fundo/chão **escuros e dessaturados** (#1A1C29 / #080A12); tudo de
gameplay **acende** com as cores acima (emissivo). É o que dá o look VECTOR neon.

---

## PARTE B — Prompts pra IA de geração 3D

Pensados pra ferramentas **text-to-3D** (Meshy, Tripo, Rodin, Luma, etc.). Em **inglês** de
propósito (esses modelos respondem melhor). Gere em **T-pose/A-pose** pra depois riggar e
animar (ver `docs/CRIACAO_DE_PERSONAGENS.md`).

### B.1 Dicas de uso
- Peça **estilo game-asset / clean topology / PBR**, não "render fotográfico".
- Peça **base body em metal/cinza neutro com faixas emissivas** na cor do personagem, pra
  o tingimento de time (azul/vermelho) funcionar por cima.
- A câmera do jogo é **top-down ~60°** → reforce **silhueta de cima distinta** (capacete,
  ombros, mochila, arma).
- Exporte/converta pra **`.glb`**, ~2 m de altura, voltado pra **−Z**, pivot nos pés.
- Gere a malha sem animação; o rig/anim entra depois (Mixamo/Godot).

### B.2 Preâmbulo de estilo (cole junto de cada prompt)
```
Style: original cyberpunk arena-fighter game character, 2.5D top-down readability,
stylized PBR game asset, clean topology, ~2m tall humanoid, neutral dark metal/gray base
body with glowing neon accent stripes, strong distinct top-down silhouette (helmet,
shoulders, backpack, weapon readable from above), emissive details, T-pose, full body,
plain background. Megacorp "VECTOR" dystopian tech. Not photorealistic.
```

### B.3 Prompts por personagem (6)

**BRECHT — o Demolidor** (acento #FF8C1A laranja)
```
BRECHT, heavy demolitions bruiser. Bulky armored frame, bandoliers of explosives across
the chest, chunky pauldrons, a stubby automatic pistol. Industrial blast-worker vibe.
Neon accent color: orange (#FF8C1A) glowing stripes. Medium build, grounded and tough.
```

**MAGNUS — o Executor** (acento #FF4D40 vermelho)
```
MAGNUS, hulking tank enforcer. The largest and widest of the roster, riot-armor plating,
heavy shoulders, carrying a big shotgun. Slow, immovable, intimidating top-down silhouette.
Neon accent color: red (#FF4D40) glowing stripes. High-mass, blocky armored profile.
```

**VESNA — a Controladora** (acento #66FF80 verde-menta)
```
VESNA, agile zone-control specialist. Slim, fast, sleek bodysuit with small antennae or
hovering drones at the shoulders, dual automatic handguns. Light and nimble silhouette.
Neon accent color: mint green (#66FF80) glowing lines. Sleek, minimal, quick.
```

**PIP — a Unidade** (acento #994DFF roxo)
```
PIP, unstable droid unit. Robotic, asymmetric chassis, exposed servos and cables, a
shoulder-mounted homing missile launcher. Erratic, glitchy, chaotic machine character.
Neon accent color: purple (#994DFF) glowing core. Mechanical, off-balance silhouette.
```

**KESTREL — o Corredor** (acento #33E6FF ciano)
```
KESTREL, hyper-fast runner. Lean lightweight frame, aerodynamic, low armor, throwing
blades on the forearms/back. Reads instantly as "speed", fragile glass-cannon. Neon accent
color: cyan (#33E6FF) glowing streaks. Slender, swift, blade-runner silhouette.
```

**MARA — a Aberração** (acento #CC66E6 magenta)
```
MARA, mutant ground-control aberration. Low, wide, hunched organic-meets-machine body,
biotech growths, a regenerating rocket-fist arm. Slow but dominating, creepy silhouette.
Neon accent color: magenta (#CC66E6) glowing veins. Organic, broad, low-profile.
```

### B.4 Negative prompt (sugestão)
```
photorealistic, realistic human skin, low-poly blocky, untextured, multiple characters,
weapons floating detached, text, watermark, T-pose missing, extra limbs, blurry.
```

---

Depois de gerar: seguir o contrato técnico de `docs/CRIACAO_DE_PERSONAGENS.md` (`.glb`,
Forward=−Z, pivot nos pés, cápsula r0.5×h2.0, anims em PT) e plugar via `StatsPersonagem`.
Cores e direção geral: este doc + `docs/ARTE.md`.
