# VAULTBREAKER — Roteiro de Playtest (o que precisa do SEU feel)

Quando você chegar em casa e puder jogar, este arquivo lista **exatamente** o que só você
pode decidir (balanceamento, feel, aprovação). O resto da estrutura está pronto e testado
(**127 testes headless passando**). Tudo que tem número fica em `.tres` (balanceável sem
código) ou em consts marcadas — me diga o que mudar e eu ajusto na hora.

## Como rodar / testar
- Abrir o projeto no Godot 4.6.3 e dar **Play (F5)**. Fluxo: Título → (Story/VS COM/VS MAN)
  → Seleção (mapa + personagem) → Arena.
- Mapas: **Padrão, Corredor, Fortaleza** (planos) e **Cruz Vertical** (com pontes/rampas).
- Dificuldade do bot no título: **Fácil / Normal / Difícil**.
- Atalho dev (sem menus): `godot --path "<proj>" -- --vertical` cai direto na arena vertical.

---

## 1. BALANCEAMENTO (me diga o que está forte/fraco/sem graça)

### Armadilhas (`resources/armadilhas/*.tres`)
Pra cada uma, sente: dano, raio, tempo pra armar, tempo de retorno ao inventário, knockback.
- **Mina** (dano 20, raio 2.2, knockback 3.5) — forte/fraca demais?
- **Bomba** (dano alto, combo com Detonador) — o combo compensa?
- **Detonador** — vale a vaga no loadout?
- **Gás** (dano 10 + slow + imobiliza, nuvem 3s, raio 4.5) — nuvem grande/pequena? tempo bom?
- **Cova** (imobiliza 2.5s) — preso tempo demais? o button-mash pra sair tá bom?
- **Painel de Força** (arremesso 9) — empurra o suficiente?

### Personagens (`resources/personagens/*.tres`)
Os 6 têm vida/velocidade/munição/loadout **exatos do GDD seção 4** (não balanceei, só montei).
Sente se cada um "joga diferente" e se algum está dominante:
- BRECHT 100/7.0 · MAGNUS 130/6.0 · VESNA 100/8.0 · PIP 100/5.5 · KESTREL 75/9.0 · MARA 100/5.5.
- Kestrel (rápido, vida baixa) e Magnus (lento, vida alta) são os extremos — funcionam?

### Combate (consts em `combatente.gd`)
- Tiro: munição base 6, cadência 0.28s, recarga 1.5s, dano 12, rapidez 22.
- Soco: alcance 1.9, dano 10, derruba 0.9s.
- **Unit/Plasma**: carga 1.8s, dano 40 (×2 em derrubado). A super tá épica ou fraca? carga rápida demais?

### IA do bot (`bot.gd`) — joga contra cada dificuldade
- Foge com vida < 30 (kite). Recua cedo/tarde demais?
- Planta Cova quando você tá perto, Mina quando longe. Faz sentido?
- Desarma suas armadilhas (1.5s parado). Dá pra punir (acertar ele) a tempo?
- Busca o Healer com pouca vida. Vai atrás cedo demais?
- **Fácil vs Difícil**: a diferença de desafio tá boa?

### Partida
- **Rounds (melhor de 3)** — 3 rounds é o ideal, ou prefere 5 / round único?
- Timer 90s por round — curto/longo?
- **Spark Bit** aos 30s — força ação o suficiente? dano (8) ok?
- Pausa entre rounds (2s) — boa?

---

## 2. FEEL / MOVIMENTO (sente e me fala)
- Velocidade do player (7) vs bot (5) — o bot te alcança fácil demais / nunca alcança?
- **Arena vertical:** ⚠ **TESTE AS RAMPAS** — o personagem sobe as 4 rampas suave? Alguma
  fica íngreme/travada? (As leste/oeste e as norte/sul.) Me diga qual ajustar.
- Oclusão da ponte (some quando passa embaixo) — funciona bem na sua visão?
- Knockdown (0.9s sem controle) — frustrante ou justo?
- Screenshake (explosão/knockdown) — forte/fraco demais?

---

## 3. APROVAR (decisões que tomei como padrão — confirma ou muda)
- **Rounds:** 2 vitórias vencem, vida cheia por round, reset de armadilhas (field traps/Vaults
  ficam). [GDD 7.3] — ok?
- **Story:** esqueleto com 3 missões placeholder (mapa+dificuldade). Como você quer a campanha
  de verdade (objetivos, chefe, diálogo)?
- **IA "faro"/desarme** do bot — comportamento aprovado?

---

## 4. ASSETS (quando você trouxer — eu plugo na hora)
- **Personagem 3D:** `.glb` em `assets/models/personagens/<nome>/` + apontar `cena_modelo`
  no `.tres`. (Kenney CC0 pra testar agora; renders→image-to-3D/Blender pro final.)
- **Chão:** `assets/sprites/chao.png` (tileável) — aparece automático.
- **Ícones de armadilha:** já plugados (`assets/sprites/armadilhas/*.png`).
- **Áudio:** `assets/audio/<evento>.wav` — o AudioManager usa automático. Eventos:
  `plantar, tiro, explodir, soco, dano, derrubado, desarme, item, vitoria`.
- Specs/prompts: `docs/CRIACAO_DE_ASSETS.md`, `docs/ARTE.md`, `docs/ARTE_PALETA_E_PROMPTS.md`.

---

## 5. Limitações conhecidas (placeholder)
- Tudo é **primitiva** (cápsula/caixa/cor) — proposital até a arte chegar.
- Áudio é **beep procedural** até você dropar os `.wav`.
- Story é **esqueleto** (sem objetivos especiais/chefe ainda).
- Online **não** implementado (design em `docs/ONLINE.md`).
- A arena vertical é **greybox** (geometria cinza) — joga pra validar o *feel*, depois skinamos.

---

Me diga, por bloco, o que ajustar — eu mexo nos `.tres`/consts e re-testo headless. Bom jogo! 🎮
