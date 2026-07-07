# DevLog

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
