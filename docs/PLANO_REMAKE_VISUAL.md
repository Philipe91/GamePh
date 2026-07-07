# Plano — Reconstrução visual/feel "igual Trap Gunner" (2026-07-06, noite)

Gatilho: playtest do humano reprovou ("fei demais.png" na raiz — ver análise abaixo).
Referências: manual (PDF na raiz), HG101, Wikipedia, SUPERJUMP (links no DevLog).

## O que o print revelou (por que ficou feio)
1. Câmera ortográfica longe + reta demais → bonecos viram bolhas vistas de cima.
2. Chão de 24×24u fixo na cena vs mapa de 40×40u → arena "flutua" num vazio preto
   riscado de linhas cianas infinitas.
3. Player e bot usam o MESMO modelo Kenney amarelo, gigante (~2 tiles de largura).
4. Field traps/itens sem material → quadrados chapados que parecem UI.
5. Nada impede sair do mapa (sem paredes) — "parece bugado".

## Como era o Trap Gunner real (pesquisa)
- Visão de cima INCLINADA (~50–60°), zoom que mostra a maior parte do mapa.
- Arenas PEQUENAS e legíveis (Port, Factory, Depot...), 2 andares, escadas/rampas/
  pontes/esteiras; chão em PLACAS/tiles bem demarcados; paredes no perímetro.
- Personagens low-poly atarracados, cores fortes, ~1 tile de largura.
- Armadilhas = decalques planos no chão (igual ao nosso disco+ícone — manter).
- Explosões com chama + fumaça espessa; brilho forte no Plasma.
- HUD: barras no topo, timer central, ícone da armadilha atual + contagem, minimapa.
- Tech PS1 = 3D poligonal simples (dev Racjin). Nada exótico: o gap é DIREÇÃO DE ARTE.

## Plano de execução (nesta ordem, print+commit por etapa)
1. **Câmera Trap Gunner**: perspectiva (FOV ~50), inclinação ~55°, segue o player com
   clamp nas bordas do mapa. Presets Normal/Quarter/Top ficam pra depois (Settings).
2. **Chão xadrez por tile** (MultiMesh, 2 tons por tema do mapa) cobrindo EXATAMENTE o
   grid + **paredes com colisão** no perímetro. Some o vazio preto e as linhas cianas.
3. **Personagens**: escala reduzida (~1.9u de altura), TINGIDOS por time (P1 azul,
   P2 vermelho) com material chapado (leitura PS1); anel de time mantido.
4. **Field traps com cara de objeto**: caixas com cor por tipo (madeira/explosiva),
   lançadores/vault legíveis no novo ângulo.
5. **Explosão**: + fumaça espessa (2ª camada de partículas) além de flash/shake/hit stop.
6. **HUD estilo Trap Gunner**: barras topo com nome, timer central grande (já tem),
   ícone da armadilha atual (já tem), minimapa (já tem) — retoques de posição.
7. Validar: suíte --teste verde + capturas de cada mapa; ajustar constantes por captura.

## Fora deste passe (Roadmap)
Split-screen do VS (marca do original), 2 andares nos mapas planos, modelos próprios
por personagem (P1 do Roadmap), SFX reais, retratos na HUD.
