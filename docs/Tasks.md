# Tasks — quadro vivo (atualizar a cada sessão)

## Em andamento (sessão 2026-07-06)
- [x] Auditoria completa (Missão 01) → relatório em BugReport/Architecture/Roadmap
- [x] Extrair testes/demos de arena.gd → scripts/dev_arena.gd
- [x] Bug: screenshake × câmera-segue
- [x] Knockback por impulso físico
- [x] Hit stop + flash de luz nas explosões
- [x] Pitch aleatório no áudio; HUD com barras animadas e timer de urgência
- [x] Spark Bit fiel ao manual; IA mina território de Vault
- [ ] Suíte --teste verde com tudo acima (validação em andamento)
- [ ] Commit local (push é do humano)

## Feito na madrugada de 2026-07-06→07 (reconstrução visual)
- [x] Câmera perspectiva 54°/FOV48/dist21 com clamp; chão xadrez MultiMesh; paredes
- [x] Personagens KayKit CC0 animados (6 do roster) + driver de animação no Combatente
- [x] Glow, itens coloridos girando, Vault pulsando, timer arcade, caixas com material
- Commits: 230c180, ba51208, 9e19e22, 809ccf7 (locais — humano dá push)

## Feito no Plano Noturno 2 (2026-07-07)
- [x] Armas por personagem (tabela ARMAS) + tracers coloridos com luz
- [x] Sangue + punch de escala no dano; fogo residual pós-explosão
- [x] IA: loadout real, combo bomba→detonador, planta na fuga, desvia de Spark Bit
- [x] Texturas ambientCG (chão metal, paredes, caixotes madeira)
- [x] Ponte-passarela, esteira animada, SFX sintetizados, retratos, morte/comemoração
- [ ] Migrar tabela ARMAS pra Resource (.tres) — anotado, baixa prioridade

## Próximas (ordem sugerida — ver Roadmap.md)
1. PLAYTEST humano do novo visual+feel → calibrar CAM_*/ALTURA_MODELO_ALVO/impulso
2. Pontes em mapa plano parecem tiles aqua flutuantes → dar volume/elevação visual
3. Esteiras sem indicação de direção (seta/animação de faixa)
4. Animações extras: morte/vitória/soco (KayKit tem; ligar no driver)
5. SFX reais + música (P2); pathfinding do bot (P3); split-screen VS (fidelidade)

## Backlog registrado
- ObjectDB leak warning no --teste (cosmético)
- chao_tile*.png sem .import (export filter ou importar)
- Story Mode real, tutorial, settings de vídeo/controles
