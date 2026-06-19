# VAULTBREAKER — Handoff (continuar de outro PC)

Documento único e autossuficiente pra retomar o projeto em outra máquina. Tudo que importa
está inline aqui; os docs detalhados ficam citados no fim.

---

## 1. Pegar o projeto

- **Repo:** `https://github.com/Philipe91/GamePh.git` (branch `main`, já com tudo).
  ```
  git clone https://github.com/Philipe91/GamePh.git
  ```
- **Engine:** Godot **4.6.3 stable**, versão **standard** (não a .NET). Baixar em godotengine.org.
- **Abrir:** abra a pasta do projeto no Godot e dê Play (F5). **Cena principal:**
  `scenes/ui/titulo.tscn` → Título → Seleção de personagem → Arena.
- **Controles (teclado):** WASD mover · Espaço plantar · F detonar · Q/E ou **Tab** (radial)
  trocar armadilha · Mouse/J atirar · K socar · U (segurar) Unit/Plasma · C (segurar)
  Caution Mode · setas inserir código de desarme · Esc pausa.

---

## 2. Estado atual (o que já existe)

Jogo **completo em mecânica** (Fases 1–9 do roadmap), **tudo com placeholder** de arte/som
(cápsulas coloridas, beeps gerados em código). **Teste headless: 99/99.**

- **Armadilhas (6):** Mina, Bomba, Detonador (+combo), Gás, Cova, Painel de Força.
- **Caution Mode** (detectar), **Desarme** (código de setas), **Retomada**, **menu radial**.
- **Combate:** projétil (munição+recarga), corpo a corpo (knockdown), **Unit/Plasma** (super),
  Vault + itens (speed/protect/healer/unit/armadilha), Spark Bit.
- **Roster:** 6 personagens (`.tres`) + tela de seleção. Modos **VS COM** e **VS MAN** (2 gamepads).
- **Mapas:** 3 mapas por dados + field traps (caixas, esteira, lançador, ponte).
- **Juice/UI:** screenshake, partículas, AudioManager, título/pausa/rematch, radar.
- **Persistência local** (vitórias/derrotas). **Online:** só design. **Export:** preset Windows.

---

## 3. O que falta (e quem faz)

| Item | Quem | Como |
|------|------|------|
| **Modelos 3D / texturas** | IA de 3D ou artista | seção 5 (prompts) |
| **Áudio real** | você / banco de sons | dropar `.wav` (seção 6) |
| **Fontes / ícones** | você | seção 6 |
| **Implementar online** | decisão sua | `docs/ONLINE.md` |
| **Buildar (export)** | você | instalar export templates 4.6.3 |
| **Plugar os assets no jogo** | **eu (código)** | me mande os arquivos |

O agente (eu) escreve código e integra; **não gera arquivos binários** (`.glb/.png/.wav`).
Assim que os assets existirem, eu plugo tudo.

---

## 4. Rodar / testar (sem travar)

- **Teste automatizado (headless, não abre janela):**
  ```
  godot --headless --path "<projeto>" -- --teste > log.txt 2>&1
  ```
  (Args do jogo vêm depois de `--`. Deve terminar com "TODOS OS TESTES PASSARAM".)
- **Screenshots de dev (renderizam e fecham sozinhos):** `--demo`, `--demo-caution`,
  `--demo-desarme`, `--demo-radial`, `--demo-combate`, `--demo-mapa`, `--demo-titulo`,
  `--demo-selecao`.
- **NUNCA** rode o Godot de forma bloqueante esperando a janela fechar.

---

## 5. Gerar a arte (prompts prontos pra IA de 3D)

Ferramentas: Meshy, Tripo, Rodin, Luma, etc. Gere em **T-pose**, peça *clean topology / PBR
game asset*, exporte **`.glb`** (~2 m de altura, frente **−Z**, pivot nos pés).

**Preâmbulo (cole junto de TODO prompt):**
> Style: original cyberpunk arena-fighter game character, 2.5D top-down readability,
> stylized PBR game asset, clean topology, ~2m tall humanoid, neutral dark metal/gray base
> body with glowing neon accent stripes, strong distinct top-down silhouette (helmet,
> shoulders, backpack, weapon readable from above), emissive details, T-pose, full body,
> plain background. Megacorp "VECTOR" dystopian tech. Not photorealistic.

**Os 6 personagens** (acento = cor de time):
- **BRECHT** (#FF8C1A): heavy demolitions bruiser, bulky armor, bandoliers of explosives, chunky pauldrons, stubby automatic pistol.
- **MAGNUS** (#FF4D40): hulking tank, largest/widest, riot-armor plating, big shotgun, immovable.
- **VESNA** (#66FF80): agile zone-control, slim sleek bodysuit, shoulder drones/antennae, dual handguns.
- **PIP** (#994DFF): unstable droid, asymmetric chassis, exposed servos/cables, shoulder homing-missile launcher, glitchy.
- **KESTREL** (#33E6FF): hyper-fast runner, lean lightweight, throwing blades, glass-cannon, reads as speed.
- **MARA** (#CC66E6): mutant ground-control, low/wide hunched organic-meets-machine, biotech growths, regenerating rocket-fist.

**Negative prompt:** photorealistic, realistic human skin, low-poly blocky, untextured,
multiple characters, floating weapons, text, watermark, extra limbs, blurry.

**Dica:** modele o corpo em **cinza-metal neutro** e ponha a cor só nas **faixas emissivas**
— a cor de time (azul P1 / vermelho P2) é aplicada por cima no jogo.

### Paleta exata (hex) — fonte da verdade
- **Time/UI:** P1 #3399FF · P2 #FF404D · Vault #33FF66 · Field trap/detectada #FFD91A · Ponte #80CCFF
- **Armadilhas:** Mina #FF8C1A · Bomba #FFD933 · Detonador #33FF80 · Gás #66FF80 · Cova #8C6647 · Painel #994DFF
- **Ambiente:** Chão #1A1C29 · Grid #00D9FF · Fundo #080A12 · Luz amb. #404761
- **FX:** Tiro #FFE659 · Plasma #994DFF · Explosão #FFB333+flash branco · Spark #FFFF4D
- **Regra:** fundo/chão **escuros**; tudo de gameplay **acende** (emissivo).

---

## 6. Plugar os assets (pontos de integração já prontos)

- **Personagem:** colocar `<nome>.glb` em `assets/models/personagens/<nome>/`. No
  `StatsPersonagem` (`resources/personagens/<nome>.tres`) o jogo já lê vida/velocidade/
  munição/loadout; falta só substituir o nó **`Malha`** (cápsula) pelo modelo e ligar as
  animações. Contrato completo: `docs/CRIACAO_DE_PERSONAGENS.md`. **Animações** (no .glb,
  nomes em PT): `parado, correr, plantar, desarmar, atirar, recarregar, atingido, preso,
  derrubado, ko`.
- **Áudio:** colocar `assets/audio/<evento>.wav`. O `AudioManager` usa automaticamente.
  Eventos: `plantar, tiro, explodir, soco, desarme, item, vitoria`.
- **Ícones das armadilhas:** entram no menu radial / marcador (usam a cor de cada tipo).
- **Fonte:** trocar a default por uma sans condensada/techno nas telas e HUD.

---

## 7. Mapa de arquivos importantes

```
GDD.md ............................ fonte de verdade do design
PROGRESSO.md ...................... estado geral
docs/PLANO_NOTURNO.md ............. diario fatia a fatia (o que foi feito)
docs/ARTE.md ...................... guia de arte (direcao visual)
docs/ARTE_PALETA_E_PROMPTS.md ..... paleta hex + prompts 3D (completo)
docs/CRIACAO_DE_PERSONAGENS.md .... contrato tecnico de personagem (.glb/rig/anim)
docs/ONLINE.md .................... design do online (Fase 8)
docs/EXPORT.md .................... como buildar (Fase 9)
scripts/stats_personagem.gd ....... Resource de personagem
scripts/stats_armadilha.gd ........ Resource de armadilha
scripts/stats_mapa.gd ............. Resource de mapa
scenes/characters/ ................ combatente (base), player, bot
scenes/traps/armadilha.* .......... as 6 armadilhas (1 cena generica)
scenes/projeteis/ ................. projetil, plasma
scenes/items/ ..................... vault, item, spark_bit
scenes/field_traps/ ............... caixa, esteira, lancador, ponte
scenes/ui/ ........................ titulo, selecao, hud, radial, radar, pausa
autoloads/ ........................ GridManager, GameManager, AudioManager, Persistencia
```

---

## 8. Próximo passo sugerido

1. Gerar **2 personagens** (com os prompts) pra testar o pipeline ponta a ponta.
2. Me mandar os `.glb` → eu troco a cápsula e ligo as animações.
3. Dropar uns `.wav` de teste → áudio na hora.
4. Iterar o resto do roster + telas com arte.

Quando voltar ao PC de casa, é só me chamar que eu sigo integrando. Bom trabalho! 🌆
