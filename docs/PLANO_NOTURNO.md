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

- [x] **A1. IA do bot.** Bot evita tiles com armadilha do player que ele já "viu"
  (desvio simples na rota); planta minas com critério (no caminho do player, não em cima
  de si); opcional: ao encostar numa armadilha do player, recua. *Teste:* bot desvia de
  mina conhecida em vez de pisar quando há rota livre.

## BLOCO B — Fase 4: Combate

- [x] **B1. Arma de projétil.** `projetil.tscn` (Area3D em linha reta, tempo de vida);
  munição + recarga (recarregar trava o tiro e dura X s = vulnerável). Player atira na
  direção que olha; bot atira no player. Dano ao acertar combatente inimigo. HUD: munição.
  *Teste:* tiro baixa o Healer do alvo; munição decrementa; recarrega ao zerar.
- [x] **B2. Corpo a corpo (knockdown).** Soco de curto alcance (botão); qualquer acerto
  **derruba** (knockdown = empurrão + breve estado sem controle). *Teste:* soco perto
  derruba e dá dano; longe não acerta.
- [x] **B3. Unit (Plasma) — a super.** Barra de carga (enche com o tempo / dano causado);
  Plasma Bomb teleguiada e limitada; se o dono toma dano/é derrubado na carga, cancela;
  evasão: a Plasma some ao colidir com explosão ou após um tempo; dano massivo em alvo
  derrubado. *Teste:* carga cheia dispara; ataque na carga cancela; plasma persegue e
  some numa explosão.
- [x] **B4. Vault (P.O.D.S.) + itens.** Ponto no mapa que cospe item periodicamente:
  Item de Armadilha, Speed Up (2× por 20s), Protect (8s), Healer (cura), Unit. Pegar
  aplica o efeito; não dá pra plantar em cima da Vault. **Spark Bit** surge aos 30s
  restantes (dano ao toque). *Teste:* Speed Up dobra a velocidade; Healer cura; Vault
  bloqueia plantio; Spark Bit aparece aos 30s.

## BLOCO C — Fase 5: Roster

- [x] **C1. `StatsPersonagem` (.tres) + refactor.** Player/bot leem `vida_max`,
  `velocidade`, `arma`, `loadout` do Resource (em vez de consts). *Teste:* aplicar um
  stats muda velocidade/vida/inventário inicial.
- [x] **C2. Os 6 personagens (.tres).** Brecht, Magnus, Vesna, Pip, Kestrel, Mara com
  arma/loadout/velocidade/vida da seção 4 do GDD. *Teste:* cada um aplica o loadout certo.
- [x] **C3. Tela de seleção de personagem.** UI simples antes da partida; o bot escolhe
  um. *Teste:* a seleção define o personagem que entra na arena.

## BLOCO D — Fase 6: Arenas e field traps

- [x] **D1. Mapa por dados.** Arena parametrizável (tamanho, spawns, tiles especiais) via
  Resource; 2–3 layouts. — `scripts/stats_mapa.gd` + `resources/mapas/{padrao,corredor}.tres`;
  GridManager.configurar_mapa() (LARGURA/ALTURA/TAMANHO_TILE viraram var); arena aplica o
  mapa (redesenha grid, posiciona spawns e Vaults). Teste 79/79.
- [x] **D2. Field traps.** Obstacle Box, Bomb Box, Laser/Rocket Launcher, Esteira
  (tile que empurra). Destrutíveis por projétil/bomba. — `scenes/field_traps/{caixa,
  esteira,lancador}.{gd,tscn}`; caixa "obstaculo" solta item / "bomba" explode+detona
  bombas; lançador dispara projétil (dono 0 = acerta os dois); esteira empurra; explosão
  de armadilha danifica o grupo "destrutiveis". Teste 83/83.
- [x] **D3. Pontes/passarelas** (tile "azul claro") pra evasão da Plasma (some a ponte ao
  ser atingida). — `scenes/field_traps/ponte.{gd,tscn}`; a Plasma checa o grupo "pontes"
  e dissolve quebrando a ponte. Teste 85/85.

## BLOCO E — Fase 7: Juice, UI e modos

- [x] **E1. AudioManager** (autoload) + sfx placeholders (plantar, explodir, tiro,
  desarme, vitória). ⚠ áudio final precisa do humano. — `autoloads/audio_manager.gd`:
  `tocar(evento)` com pool de players; sons são beeps procedurais (usa `assets/audio/
  <evento>.wav` se existir). Ligado em explodir/tiro/plantar/soco/desarme/item/vitória.
  Teste 91/91.
- [x] **E2. Juice:** partículas nas explosões/acertos, screenshake na câmera, flash.
  — `scenes/arena/camera_tremor.gd` (câmera no grupo "camera", `tremer(intensidade)` com
  decaimento) + `scenes/arena/explosao_fx.{gd,tscn}` (CPUParticles one-shot). Explosão de
  armadilha chama screenshake + spawna o FX. [nota: `script` precisa vir 1º no .tscn de
  CPUParticles, senão não anexa]. Teste 93/93.
- [x] **E3. Menus:** título, seleção, pausa, fim com rematch. — `scenes/ui/titulo.{gd,
  tscn}` (nova cena principal, Título→Seleção→Arena; encaminha sob `--…`); `scenes/ui/
  pausa.{gd,tscn}` (ESC alterna, process_mode ALWAYS); HUD: rematch com Enter no fim.
  Teste 95/95.
- [x] **E4. Modos:** VS COM (atual) e VS MAN (2 jogadores local, input dividido);
  esqueleto de Story. — input do Player parametrizado por dispositivo (`jogador_num`,
  helpers `_tecla/_botao/_eixo/_mouse`; p2 = gamepad 1, sem teclado); `GameManager.modo`;
  arena troca o bot por um 2º Player no VS MAN; título com botões VS COM/VS MAN. Teste 97/97.
- [x] **E5. Radar/minimapa** com as cores do GDD seção 11. — `scenes/ui/radar.gd` (nó na
  HUD): desenha grupos vaults(verde)/pontes(azul claro)/destrutiveis(amarelo)/combatentes
  (azul=p1, vermelho=p2). `mundo_para_radar()` testável. Teste 98/98. **FASE 7 COMPLETA.**

## BLOCO F — Fase 8: Camada moderna

- [x] **F1. Persistência local** (settings, progressão simples). — `autoloads/
  persistencia.gd` (ConfigFile em `user://`): set/get_config, salvar/carregar,
  registrar_resultado (vitórias/derrotas); GameManager grava no fim da partida. Teste 99/99.
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
- **Fase 6 ✅ (`ae6e89a`, `77b7d03`, +D4)** D1 mapa por dados (`StatsMapa`, grid configurável,
  2 mapas); D2 field traps (`scenes/field_traps/{caixa,esteira,lancador}`); D3 pontes
  (dissolvem a Plasma); D4 (extra) field traps fiados nos mapas via `StatsMapa.{obstaculos,
  bombas_caixa,esteiras,pontes,lancadores}` + arena `_colocar_field_traps()` + 3º mapa
  `fortaleza.tres`. Fix: `change_scene_to_file` deferido na seleção (sem warning de árvore
  ocupada). **3 mapas jogáveis com field traps** — critério da Fase 6 atingido. Teste 88/88.
- **A1 ✅** IA do bot: faro de armadilhas — `bot._desvio_de_armadilhas()` empurra a rota
  pra longe das armadilhas do player no raio 2.6m (`PESO_DESVIO` 1.6). [decisão noturna:
  bot tem "faro" simples em vez de usar o Caution Mode completo na IA]. Teste 40/40.
  **Fase 3 COMPLETA.** Próximo: B1.
- **B1 ✅** Arma de projétil: `scenes/projeteis/projetil.{gd,tscn}` (Area3D reto, vida 2s);
  arma no `Combatente` (munição 6, cadência 0.28s, recarga 1.5s travando o tiro, dano 12,
  rapidez 22). Player atira (mouse esq / J / R2), bot atira encarando o player a <14m.
  HUD com munição. [decisão noturna: tiro na direção que encara; mira livre depois].
  Teste 44/44. Próximo: B2 (corpo a corpo).
- **B2 ✅** Corpo a corpo: `socar()` no Combatente (alcance 1.9m, dano 10, cooldown 0.6s)
  acerta o inimigo mais perto e o DERRUBA (`derrubar()` = empurrão + 0.9s sem controle).
  Derrubado não anda/atira/soca. Player soca com K/Y; bot soca colado. Teste 47/47.
  Próximo: B3 (Unit/Plasma).
- **B3 ✅** Unit/Plasma: `scenes/projeteis/plasma.{gd,tscn}` teleguiada, dano 40 (×2 em
  derrubado), some em explosão (grupo "explosoes") / após 6s. Combatente: `conceder_unit`,
  carga 1.8s (segurar U / L2), dispara ao completar; dano na carga cancela; knockdown na
  carga QUEBRA o lançador. HUD mostra carga/estoque. Teste 53/53. Próximo: B4 (Vault).
- **B4 ✅** Vault + itens + Spark Bit: `scenes/items/{vault,item,spark_bit}.{gd,tscn}`.
  Vault marca o tile (não planta) e cospe itens em ciclo. Itens: armadilha(+1), speed(2×
  20s), protect(8s, não barra Plasma), healer(+40), unit. `receber_dano(qtd, tipo_dano)`
  ganhou o tipo "plasma" que fura o Protect. Spark Bit (dano ao toque) nasce aos 30s
  (GameManager.faltam_30s → arena). Arena já põe uma Vault no centro nas partidas.
  **FASE 4 (COMBATE) COMPLETA.** Teste 61/61. Próximo: Bloco C (Fase 5 — Roster).
- **C1 ✅** `scripts/stats_personagem.gd` (Resource): nome, cor, vida_max, velocidade,
  municao_max, arma, loadout. Combatente lê no `_ready` (vida/velocidade/munição) e o
  player monta o inventário do loadout (`inventario_max` capa recarga/retomada). HUD lê
  os máximos do personagem. [decisão noturna: usar preload do StatsPersonagem como const,
  não o class_name global — senão não resolve em headless]. Teste 66/66.
- **C2 ✅** `resources/personagens/{brecht,magnus,vesna,pip,kestrel,mara}.tres` com os
  loadouts/arma/velocidade/vida da seção 4 do GDD (Magnus vida 130, Kestrel 75/veloz, etc).
  Teste 72/72. Próximo: C3 (tela de seleção).
- **C3 ✅** `scenes/ui/selecao.{gd,tscn}`: tela com os 6, ao escolher grava no GameManager
  (`personagem_jogador/_bot`) e vai pra arena; bot pega o próximo. `aplicar_personagem()`
  troca em runtime (Combatente + player refaz loadout). Cena PRINCIPAL agora é a seleção;
  com qualquer arg `--…` ela encaminha direto pra arena (testes/demos intactos). Teste
  **76/76**. **FASE 5 (ROSTER) COMPLETA — meta da noite atingida.** Próximo: Bloco D
  (Fase 6 — arenas e field traps), seguindo enquanto houver fila.
