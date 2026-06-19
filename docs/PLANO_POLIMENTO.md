# VAULTBREAKER — Plano de trabalho autônomo

> **PIVÔ (2026-06-19):** o humano pediu pra focar em **desenvolver o JOGO (gameplay)**, não
> no visual — o design/arte fica pra quando houver assets reais (o greybox parece amador
> de propósito). Então P3–P7 (cosméticos) ficam **PAUSADOS**; a fila ativa agora é
> **GAMEPLAY** (mais abaixo).

Fila de fatias **(só código, sem depender de asset 3D/áudio ou playtest do humano)**. O
agente desce a fila, **commita E dá push** em cada fatia, manda screenshot nos marcos.

## Fila de GAMEPLAY (ativa)
- [x] **G1. IA do bot — profundidade.** Recua/kite com pouca vida (atira de costas),
  planta armadilhas variadas (Cova perto / Mina longe), usa a Unit quando tem. 110/110.
- [x] **G2. Níveis de dificuldade do bot** (fácil/normal/difícil) no título. Ajusta cadência
  de armadilha, mira (limiar do tiro), teto de armadilhas, kite e velocidade. 112/112.
- [ ] **G3. Sistema de rounds** (melhor de 3) — estrutura de partida.  *(checar design no GDD)*
- [x] **G4. Bot desarma armadilhas do player** (GDD 6.4): ao encostar (≤1.7m) numa
  armadilha do player, o bot para 1.5s e a remove; tomar dano interrompe e re-arma (o
  player pode salvar a armadilha acertando o bot). Só normal/difícil. 113/113.
- [x] **G6. Bot busca itens da Vault**: com pouca vida corre pro Healer (até 16m); senão
  pega itens próximos (≤7m) por oportunidade. Movimento mira o item, combate mira o player.
  115/115.
- [ ] **G5. Passe de balanceamento** dos `.tres` — ⚠ precisa do seu PLAYTEST (não dá pra
  "sentir" daqui); fica pra quando você jogar e me disser o que está forte/fraco.

## Guardrails
1. **Commit + push** a cada fatia (workflow atual é manter o GitHub sincronizado).
2. Só tarefas que **não precisam de asset novo** nem de eu sentir o movimento. Skinnar /
   personagens 3D ficam pro humano trazer os `.glb`.
3. Cada fatia: implementar → **teste headless** → só commitar se 100% passa → push.
4. Nunca rodar o Godot bloqueante (testes `--headless --teste`; screenshots `--demo*`).
5. Atualizar o DIÁRIO abaixo a cada fatia.

## Fila
- [x] **P1. Menus premium** — título/seleção com botões de neon (hover glow), fundo
  escuro com acento no topo, logo com brilho. `scenes/ui/ui_estilo.gd` (estilizar_botao /
  titulo_glow / fundo_neon); personagens com botão na cor de time. 108/108.
- [x] **P2. Tela de fim premium** — VITÓRIA(verde)/DERROTA(vermelho)/EMPATE(amarelo) com
  texto em glow e painel escuro com borda neon na cor do resultado. `--demo-fim`. 108/108.
- [ ] **P3. Marcador da armadilha no chão** — usa o ícone mini do tipo (discreto pro
  inimigo; respeita a regra de visibilidade da armadilha).
- [ ] **P4. Radar premium** — borda neon, glow nos pontos, fundo com vinheta.
- [ ] **P5. Escadas na arena vertical** — tipo de estrutura "escada" (degraus) + um mapa
  que usa.
- [ ] **P6. Câmera com juice** — leve zoom-in suave no início da partida.
- [ ] **P7. Mais um mapa vertical** — layout novo por dados (ex.: torre/níveis) pra variar.

## DIÁRIO
- (início) Plano criado em 2026-06-19 sobre `d6b1aad`. P1/P2 (menus/fim premium) feitos.
  PIVÔ pra gameplay: G1 (IA profunda), G2 (dificuldades), G4 (bot desarma), G6 (bot busca
  itens) — todos feitos e pushados (115 testes).
- **PARADA (loop autônomo encerrado):** sobraram só G3 (rounds — precisa aprovação de
  design do humano) e G5 (balanceamento — precisa PLAYTEST do humano). Aguardando o humano
  pra: aprovar rounds, jogar e dar feedback de balanceamento, ou apontar novo rumo.
- **P1 ✅** Menus premium: `ui_estilo.gd` compartilhado (botões neon com hover glow, título
  com glow, fundo escuro + acento). Aplicado em título (VS COM ciano / VS MAN vermelho) e
  seleção (mapas ciano, personagens na cor de time). 108/108. Próximo: P2 (tela de fim).
- **P2 ✅** Tela de fim premium: cor por resultado (vitória verde / derrota vermelho /
  empate amarelo), texto com glow e painel escuro com borda+glow neon. `--demo-fim`.
  108/108. Próximo: P3 (marcador da armadilha no chão com ícone).

## NOVA FILA AUTÔNOMA (humano, 2026-06-19, longe de casa — sem playtest)
Aprovado adiantado: G3 rounds. Ordem: G3 → conferir Fase 5/6 (já feitas) → Fase 7 (settings,
Story skeleton) → ganchos de áudio/juice → persistência de settings → cobertura de testes →
placeholders. Ao esgotar, criar PLAYTEST.md e parar.
- **G3 ✅** Rounds melhor de 3 (GameManager: v1/v2/round_num, round_comecou/round_acabou/
  placar_mudou; pausa entre rounds; arena reseta posições+vida+armadilhas; HUD placar +
  "ROUND N"). GDD 7.3 atualizado. 120/120.
- **Settings ✅** tela de volume + persistência (Persistencia). `--demo-settings`. 122/122.
- **Story ✅** esqueleto navegável (3 missões -> mapa/dificuldade -> seleção). GDD 12. 122/122.
- **Áudio/juice ✅** sons "dano"/"derrubado" + screenshake no knockdown. 123/123.
- **Chão plug-and-play ✅** carrega assets/sprites/chao.png automático.
- **Cobertura ✅** reiniciar()/limpar_armadilhas testados. **127 testes.**
- **Fase 5/6 conferidas:** já estavam completas (6 personagens .tres com valores do GDD +
  seleção; 3+1 mapas com Vaults e field traps). Nada a refazer.
- **FILA AUTÔNOMA ESGOTADA.** Criado `PLAYTEST.md` com tudo que precisa do feel/playtest do
  humano (balanceamento, rampas verticais, aprovações). Parando e avisando. Sobra só G5.
