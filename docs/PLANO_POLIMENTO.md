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
- [ ] **G4. Bot usa Caution Mode/desarme** nas armadilhas do player (GDD 6.4).
- [ ] **G5. Passe de balanceamento** dos `.tres` (tempos/dano/velocidade) pro feel.

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
- (início) Plano criado em 2026-06-19 sobre `d6b1aad` (108 testes, HUD/roda premium,
  arena vertical data-driven, seleção de mapa). Começando por P1.
- **P1 ✅** Menus premium: `ui_estilo.gd` compartilhado (botões neon com hover glow, título
  com glow, fundo escuro + acento). Aplicado em título (VS COM ciano / VS MAN vermelho) e
  seleção (mapas ciano, personagens na cor de time). 108/108. Próximo: P2 (tela de fim).
- **P2 ✅** Tela de fim premium: cor por resultado (vitória verde / derrota vermelho /
  empate amarelo), texto com glow e painel escuro com borda+glow neon. `--demo-fim`.
  108/108. Próximo: P3 (marcador da armadilha no chão com ícone).
