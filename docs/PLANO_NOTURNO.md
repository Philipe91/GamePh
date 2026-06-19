# VAULTBREAKER — Plano de trabalho autônomo (noturno)

Fila de fatias da Fase 3 (fim) até a Fase 9 (export). O agente trabalha **uma fatia por
vez**, do topo pra baixo, e marca `[x]` ao concluir. Diário no fim do arquivo.

## Guardrails (combinados com o humano em 2026-06-18)

1. **Commits locais só** — NÃO dar push. De manhã o humano revisa e decide o push.
2. **Decisão de design não prevista no GDD:** tomar a mais razoável (base = Trap Gunner),
   registrar no `GDD.md` com nota `[decisão noturna 2026-06-18]` e seguir. Não travar.
3. **Cada fatia:** implementar → rodar teste headless → **só commitar se 100% passa**. Se
   não passar e não resolver rápido, deixar anotado no diário (sem commit quebrado) e
   pular pra próxima fatia independente.
4. **Nunca** rodar o Godot de forma bloqueante. Testes: `--headless ... -- --teste`.
   Screenshots: modos `--demo*` (renderizam e dão `quit()` sozinhos). Ver
   `memory/rodar-godot-sem-travar`.
5. Uma fatia por commit, mensagem clara em PT; atualizar `GDD.md` e `PROGRESSO.md`.
6. Atualizar o **DIÁRIO** abaixo a cada fatia (é o relatório da manhã).
7. Arte/áudio finos, online e export real dependem de assets/infra do humano — fazer o
   **scaffolding + placeholders** e marcar `⚠ precisa do humano` quando for o caso.

---

## BLOCO A — Fecha a Fase 3

- [ ] **A1. IA do bot.** Bot evita tiles com armadilha do player que ele já "viu"
  (desvio simples na rota); planta minas com critério (no caminho do player, não em cima
  de si); opcional: ao encostar numa armadilha do player, recua. *Teste:* bot desvia de
  mina conhecida em vez de pisar quando há rota livre.

## BLOCO B — Fase 4: Combate

- [ ] **B1. Arma de projétil.** `projetil.tscn` (Area3D em linha reta, tempo de vida);
  munição + recarga (recarregar trava o tiro e dura X s = vulnerável). Player atira na
  direção que olha; bot atira no player. Dano ao acertar combatente inimigo. HUD: munição.
  *Teste:* tiro baixa o Healer do alvo; munição decrementa; recarrega ao zerar.
- [ ] **B2. Corpo a corpo (knockdown).** Soco de curto alcance (botão); qualquer acerto
  **derruba** (knockdown = empurrão + breve estado sem controle). *Teste:* soco perto
  derruba e dá dano; longe não acerta.
- [ ] **B3. Unit (Plasma) — a super.** Barra de carga (enche com o tempo / dano causado);
  Plasma Bomb teleguiada e limitada; se o dono toma dano/é derrubado na carga, cancela;
  evasão: a Plasma some ao colidir com explosão ou após um tempo; dano massivo em alvo
  derrubado. *Teste:* carga cheia dispara; ataque na carga cancela; plasma persegue e
  some numa explosão.
- [ ] **B4. Vault (P.O.D.S.) + itens.** Ponto no mapa que cospe item periodicamente:
  Item de Armadilha, Speed Up (2× por 20s), Protect (8s), Healer (cura), Unit. Pegar
  aplica o efeito; não dá pra plantar em cima da Vault. **Spark Bit** surge aos 30s
  restantes (dano ao toque). *Teste:* Speed Up dobra a velocidade; Healer cura; Vault
  bloqueia plantio; Spark Bit aparece aos 30s.

## BLOCO C — Fase 5: Roster

- [ ] **C1. `StatsPersonagem` (.tres) + refactor.** Player/bot leem `vida_max`,
  `velocidade`, `arma`, `loadout` do Resource (em vez de consts). *Teste:* aplicar um
  stats muda velocidade/vida/inventário inicial.
- [ ] **C2. Os 6 personagens (.tres).** Brecht, Magnus, Vesna, Pip, Kestrel, Mara com
  arma/loadout/velocidade/vida da seção 4 do GDD. *Teste:* cada um aplica o loadout certo.
- [ ] **C3. Tela de seleção de personagem.** UI simples antes da partida; o bot escolhe
  um. *Teste:* a seleção define o personagem que entra na arena.

## BLOCO D — Fase 6: Arenas e field traps

- [ ] **D1. Mapa por dados.** Arena parametrizável (tamanho, spawns, tiles especiais) via
  Resource; 2–3 layouts.
- [ ] **D2. Field traps.** Obstacle Box, Bomb Box, Laser/Rocket Launcher, Esteira
  (tile que empurra). Destrutíveis por projétil/bomba.
- [ ] **D3. Pontes/passarelas** (tile "azul claro") pra evasão da Plasma (some a ponte ao
  ser atingida).

## BLOCO E — Fase 7: Juice, UI e modos

- [ ] **E1. AudioManager** (autoload) + sfx placeholders (plantar, explodir, tiro,
  desarme, vitória). ⚠ áudio final precisa do humano.
- [ ] **E2. Juice:** partículas nas explosões/acertos, screenshake na câmera, flash.
- [ ] **E3. Menus:** título, seleção, pausa, fim com rematch.
- [ ] **E4. Modos:** VS COM (atual) e VS MAN (2 jogadores local, input dividido);
  esqueleto de Story.
- [ ] **E5. Radar/minimapa** com as cores do GDD seção 11.

## BLOCO F — Fase 8: Camada moderna

- [ ] **F1. Persistência local** (settings, progressão simples).
- [ ] **F2. Online** — ⚠ FORA do escopo noturno (precisa infra/decisão do humano);
  deixar só um documento de design.

## BLOCO G — Fase 9: Export

- [ ] **G1. Preset de export PC (Windows)** + ícone + config. ⚠ validar export pode
  precisar de templates baixados pelo humano.

---

## DIÁRIO (relatório da manhã)

> O agente escreve aqui a cada fatia: data/hora aproximada, o que fez, commit, testes,
> decisões noturnas tomadas, e o que ficou pendente.

- (início) Plano criado. Fase 3 estava em `2392687` (37/37 testes). Começando por A1.
