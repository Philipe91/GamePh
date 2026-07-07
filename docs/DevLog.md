# DevLog

## 2026-07-07 (parte 4) — Missão de Direção de Arte (sem tocar gameplay)

Auditoria de assets (inventário completo em Architecture.md) e passe de identidade:
- **Tipografia**: Orbitron (OFL, Google Fonts) como fonte padrão do projeto
  (`gui/theme/custom_font`) — HUD, menus e telas inteiras com cara própria de uma vez.
- **Iluminação/grading**: tonemap ACES + contraste 1.06 + saturação 1.12, ambiente
  0.6→0.85 (sem áreas mortas), sombras suaves (shadow_blur 1.6 + angular_distance 2°).
- **Consistência de personagens**: Kenney Character REMOVIDO do projeto (destoava da
  família KayKit); fallback sem stats agora é o KayKit Knight tingido pela cor do time.
  Demo --demo-modelo atualizada.
- **Partículas de vida**: poeira nos pés ao correr; burst de brilho NA COR do item ao
  coletar. (Explosão já tinha fogo/fumaça/onda/flash; sangue no dano.)
- **Higiene**: `_captura_arena.png` fora do versionamento (artefato de dev).
- Direção assumida e documentada: stylized/limpo (KayKit + Quaternius + cores chapadas
  com temas por mapa); texturas ambientCG mantidas como acento sutil, não realismo.


## 2026-07-07 (parte 3) — Passe de acabamento "Steam" (feedback do playtest)

Humano: "ainda com cara de não terminado; paredes; IA burra; corrija bugs".
- **Paredes de verdade**: base 1.7u texturizada + FRISO NEON no topo na cor do tema
  do mapa + pilares nos 4 cantos — a arena fecha como um ringue.
- **BUG DE FIDELIDADE corrigido — armadilha inimiga agora é INVISÍVEL de verdade**
  (alma do Caution Mode; antes aparecia um disco translúcido + corpo 3D pra todo
  mundo): cada armadilha renderiza na camada do dono (11/12) e cada câmera corta a
  camada do adversário via cull_mask (funciona também no split-screen — mind games).
  Gás emitindo e explosões voltam à camada visível (perigo ativo todos veem).
- **IA v2**: em média distância ORBITA o player (strafe circular com troca de lado
  imprevisível) em vez de andar reto; ENCARA o alvo em alcance de combate (atira
  muito mais); ESQUIVA pro lado de projéteis vindo na direção dela.
- **Aim assist** (todos os atiradores): inimigo num cone de 30° à frente, o tiro sai
  nele; fora do cone sai reto — mira por movimento ficou justa sem ficar automática.


## 2026-07-07 (parte 2) — Split-screen, pathfinding e Story Mode real

- **SPLIT-SCREEN no VS MAN** (decisão do humano: dividida SÓ no multiplayer local):
  dois SubViewports lado a lado compartilhando o mundo (`own_world_3d = false`), cada
  um com câmera própria (preset atual + screenshake + clamp) seguindo o seu jogador.
  VS COM continua tela única. `arena._montar_split_screen`.
- **Pathfinding A\*** (`GridManager.caminho_mundo`, AStarGrid2D diagonal-safe): caixas
  e lançadores marcam o tile como sólido ao nascer (limpam ao morrer). O bot persegue
  por WAYPOINTS (recalcula a cada 0.5s) — parou de esbarrar em caixa; fuga continua
  direta (correr é reação, não plano).
- **Story Mode de verdade**: 5 missões (Treinamento, Porto de Carga com DESARME 3,
  Fábrica, O Cerco com SOBREVIVER, Setor 07 chefe), travas de progresso persistidas
  (`story/missao`), objetivos no GameManager ("desarmes" vence a partida ao cumprir;
  "sobreviver" decide o tempo pela sobrevivência) e HUD de objetivo com progresso.
- Suíte: 141 → **148 asserções** (A*, split, objetivos). Push contínuo pro GamePh.


## 2026-07-07 — Assets de armas e armadilhas (+ push habilitado)

- Push liberado pelo humano para `github.com/Philipe91/GamePh` (remoto `origin` já
  apontava pra lá). Fluxo agora: commit + push a cada progresso.
- **Armas 3D (Quaternius, CC0)** em `assets/models/armas/<arma>.fbx` (pistola, shotgun,
  handgun=Ray Gun, missil=Lightning Gun, laminas=Dagger; soco_foguete fica de mão
  livre). Montadas na mão direita do personagem com auto-escala pela AABB
  (`combatente._montar_arma_visual`). Fonte: mirror beep2bleep no GitHub.
- **Armadilhas com corpo 3D** por tipo em cima do decalque (cúpula/esfera/caixinha/
  tambor/aro/seta — a seta do Painel aponta pro arremesso). O corpo usa o MESMO
  material do decalque, então respeita as regras de visibilidade (discreta pro
  inimigo, acende ao armar/explodir).


## 2026-07-07 (madrugada, parte 2) — Plano Noturno 3

- **3 câmeras do original**: Normal/Quarter/Top na tecla **V** (persiste em settings) —
  fidelidade direta ao Trap Gunner (tabela CAM_PRESETS em arena.gd).
- **Radar fiel ao GDD 11**: armadilhas inimigas detectadas no Caution piscam em
  amarelo; itens no chão aparecem em verde-claro.
- **Mapa novo "Porto"** (24×14, homenagem ao Port do original): corredor central de
  esteiras duplas, Bomb Boxes nos gargalos, cannon ao sul, tema azul-petróleo.
  Corredor (âmbar industrial) e Fortaleza (roxo) ganharam temas de cor próprios.
- **Música procedural** (loop kick+baixo Lá menor+hat, ~4.8s, LOOP_FORWARD) tocando
  do menu à arena; troca automática por `assets/audio/musica.ogg` quando existir.
- **Onda de choque** nas explosões (anel expandindo com fade — vende o raio do dano).
- **Avental** escuro sob a arena (fim do "vazio preto" além das paredes) e **feixe de
  luz vertical nas Vaults** (o ponto de interesse aparece de longe, como no original).
- Demos: `--demo-porto` novo; `--demo-padrao` refatorado pra função genérica de mapa.


## 2026-07-07 (madrugada) — Plano Noturno 2 (docs/PLANO_NOTURNO_2.md)

- **Armas reais por personagem** (tabela `ARMAS` em combatente.gd, specs do GDD 4/FAQ):
  pistola, shotgun com leque de 5 pellets curto, handgun metralha, míssil teleguiado
  que DERRUBA, lâminas rápidas, soco-foguete teleguiado. Projéteis com cor por arma +
  luz própria (tracer com o glow). Confirmado no Fandom: míssil da Tico teleguiado;
  Rocket Fist do Abdoll com knockdown — nossos Pip/Mara.
- **Sangue e impacto**: respingo vermelho + punch de escala no modelo em todo dano.
- **IA**: usa o LOADOUT do personagem (cada oponente joga diferente); combo assinatura
  bomba→detonador com gatilho quando o player pisa no raio; planta armadilha ao FUGIR
  (fuga vira emboscada); desvia de Spark Bit.
- **Texturas ambientCG (CC0)**: placas de metal no chão xadrez (1 placa/tile, tingida
  pelo tema) e paredes (triplanar); caixotes de madeira (Bomb Box tingida de vermelho).
- **Ponte** virou passarela real (deck+pilares+corrimão); **esteira** com faixas
  deslizantes na direção do empurrão.
- **Fogo residual** ~0.9s após explosões (emissor "Chamas" no explosao_fx).
- **SFX sintetizados** de verdade (seno+ruído com varredura e envelope): explosão grave,
  tiro seco, chimes. Suporte a .wav externo mantido.
- **Retratos oficiais KayKit** na HUD (ao lado das barras) e na tela de seleção.
- **Animações de morte e comemoração** (vencedor do round faz Cheer na pausa).


## 2026-07-06 (noite) — Reconstrução visual "igual Trap Gunner" + personagens animados

Playtest do humano reprovou o visual ("fei demais.png"): câmera reta de cima, chão que
não cobria o mapa, vazio preto com linhas neon, dois bonecos amarelos idênticos gigantes.
Plano completo em `docs/PLANO_REMAKE_VISUAL.md` (com a pesquisa do jogo original —
HG101/Wikipedia/SUPERJUMP: visão inclinada com zoom, arenas pequenas legíveis em placas,
personagens low-poly atarracados, armadilha = decalque no chão, explosão com fumaça).

Executado:
- **Câmera**: perspectiva FOV 48, inclinação 54°, dist 21, segue o player com CLAMP nas
  bordas (não mostra o vazio). Constantes em arena.gd (CAM_*).
- **Chão xadrez** por tile (MultiMesh 2 draw calls, cores tema no StatsMapa:
  `cor_tile_a/b`) cobrindo exatamente o grid + **paredes com colisão** no perímetro
  (antes dava pra andar pro infinito). Linhas neon removidas em mapas planos.
- **Personagens KayKit (CC0, Kay Lousberg)** baixados de github.com/KayKit-Game-Assets:
  Barbarian→Brecht, Knight→Magnus, Mage→Vesna, Rogue→Kestrel, Skeleton_Minion→Pip,
  Skeleton_Warrior→Mara (`assets/models/kaykit/`, licenças junto). Riggados e ANIMADOS.
- **Driver de animação** no Combatente: acha o AnimationPlayer do modelo, resolve
  Idle/Running/Hit por nome (com fallback por substring), força loop, troca por estado
  (parado/correndo/derrubado) com blend 0.2s. O corpo agora SE MOVE.
- **Auto-escala** de modelo pela AABB (altura-alvo 2.5u) — acaba com gigante/anão.
- Tinta de time só no modelo fallback; anel do chão SEMPRE azul (P1) / vermelho (P2).
- Caixas com material por tipo (madeira/explosiva); explosão com fumaça espessa.


## 2026-07-06 — Auditoria completa + passe de feel/correções (Missões 01–03)

**Auditoria (Missão 01).** Lidos todos os 33 scripts (~4.9k linhas), cenas, resources
e docs. Baseline da suíte headless: verde. Conclusão: as Fases 1–9 do GDD existem e
funcionam; o que falta é qualidade (arte/som placeholders), feel e fidelidade fina ao
manual. Achados completos em `docs/BugReport.md`; estado consolidado em
`docs/Architecture.md`; prioridades em `docs/Roadmap.md`.

**Refatoração.** `arena.gd` (1489 linhas) dividido: testes+demos → `scripts/dev_arena.gd`
(novo dono da suíte `--teste` e das capturas `--demo-*`); arena ficou só produção.

**Correções.**
- Screenshake não briga mais com a câmera-segue (offset composável) — antes, toda
  explosão teleportava a câmera pro spawn nos mapas grandes.
- Ícones da HUD/roda agora usam textura importada (export-safe), fallback dev mantido.

**Feel (Trap Gunner FAQ como bíblia; valida em playtest).**
- Knockback virou IMPULSO físico com decaimento: o corpo desliza com peso e respeita
  parede — mina empurra, painel arremessa (~9u), knockdown desliza (~3u).
- Hit stop: `GameManager.hit_stop()` — soluço de 50ms a 15% nas explosões, 40ms no soco.
- Explosão ganhou FLASH de luz (OmniLight com fade 0.4s) além de partícula+shake+som.
- SFX com pitch aleatório ±8% (mata a repetição dos beeps).
- HUD: Healer desce/sobe animado com flash de dano/cura; timer amarelo <30s (aviso do
  Spark Bit) e vermelho pulsante <10s.

**Fidelidade ao manual.**
- Spark Bit: agora vagueia (forma viva), morre SÓ com explosão e regenera em 8s.
- IA territorial: perto de uma Vault o bot planta MINA (nega o ponto de interesse) —
  o item vira isca, como no jogo original.

**Testes.** Suíte ampliada: impulso do painel, spark bit (morte/regeneração), luz do
FX, hit stop (desacelera E restaura), bot minando território de Vault.

Histórico anterior: `PROGRESSO.md` (fases 1–9) e `docs/PLANO_NOTURNO.md` (diário).
