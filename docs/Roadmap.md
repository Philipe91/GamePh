# Roadmap — remake definitivo (pós-auditoria 2026-07-06)

Estado: Fases 1–9 do GDD implementadas com placeholders. O que falta pra qualidade
comercial está abaixo, por prioridade. Regra: uma fatia por vez, suíte `--teste`
verde antes de cada commit, feel valida em playtest humano.

## P0 — Feel e correções (EM ANDAMENTO nesta sessão)
- [x] Screenshake compatível com câmera-segue (bug corrigido)
- [x] Knockback físico por impulso (sem teleporte)
- [x] Hit stop leve em explosão e knockdown
- [x] Flash de luz nas explosões (OmniLight com fade)
- [x] Variação de pitch nos SFX
- [x] HUD: barras de Healer animadas c/ flash de dano/cura; timer com urgência
- [x] Spark Bit fiel ao manual (morre só com explosão, regenera, vagueia)
- [ ] PLAYTEST humano do feel (movimento, knockback, hit stop) → ajustar constantes

## P1 — Identidade visual (próxima grande frente)
- [ ] Personagens: substituir cápsulas/Kenney por pack estilizado consistente
      (Quaternius/Kenney characters + Mixamo p/ animações: idle/walk/run/hit/death/victory)
      → proposta de pack única antes de integrar (ver docs/CRIACAO_DE_PERSONAGENS.md)
- [ ] AnimationTree por personagem (locomoção 2D blend + one-shots)
- [ ] Armadilhas com malha própria por tipo (hoje: disco colorido + ícone 2D)
- [ ] Arena: kit modular (chão/parede/pilar texturizados, props), skybox/ambiente
- [ ] Post-processing: glow (WorldEnvironment), vinheta leve, correção de cor

## P2 — Áudio
- [ ] SFX reais (freesound/kenney audio) substituindo beeps; manter fallback procedural
- [ ] Música de menu + arena (loop), ducking no fim de round
- [ ] Espacialização (AudioStreamPlayer3D nos emissores de mundo)

## P3 — IA de verdade
- [ ] NavigationRegion3D/pathfinding nos mapas verticais (hoje: linha reta + desvio)
- [ ] Caution Mode do bot (detectar e desarmar com risco, não por proximidade mágica)
- [ ] Emboscada: plantar combos (bomba+detonador) e atrair o player
- [ ] Personalidade por personagem (usa o loadout do .tres, não kit fixo mina/cova/gas)

## P4 — Conteúdo e modos
- [ ] Story Mode real (diálogo, objetivos de desarme, chefe VECTOR)
- [ ] +2 mapas com identidade (tema visual + field traps próprios)
- [ ] Tela de seleção com retratos/preview 3D
- [ ] Tutorial/onboarding (ensina Caution/desarme/combos)

## P5 — Lançamento
- [ ] Export Windows assinado + página Steam (capsule art, screenshots, trailer)
- [ ] Settings completos (vídeo, remapeamento de controles)
- [ ] Online (docs/ONLINE.md — decisão do humano, fase 8)
