# BugReport — bugs encontrados e status

Formato: data · gravidade · descrição · causa · correção.

## Corrigidos (2026-07-06, auditoria Missão 01)

1. **ALTA — Explosão teleportava a câmera pro spawn** em mapas com câmera-segue
   (padrão 20×20, Setor 07). Causa: `camera_tremor.gd` guardava `_base = position` no
   `_ready` e restaurava ao fim do tremor, desfazendo o follow. Correção: shake virou
   offset aplicado/removido por frame (compõe com qualquer movimento de câmera).

2. **MÉDIA — Knockback por teleporte**: `aplicar_empurrao` somava direto em
   `global_position` (atravessava paredes nos mapas verticais; feel "congelado").
   Correção: impulso físico em `Combatente` (decai a λ=8/s, integra no move_and_slide
   de player/bot, distância total preservada ≈ força). Testes ajustados.

3. **MÉDIA — Ícones quebravam no export**: HUD e menu radial liam PNG via
   `FileAccess`+`Image.load` (no export o PNG cru não existe no PCK, só o .ctex).
   Correção: preferir `load()` da textura importada; `Image.load` só como fallback dev.

4. **BAIXA — Spark Bit infiel ao manual**: não morria com bomba, não regenerava, era
   estático. Correção: entra em `destrutiveis` (explosões o matam), regenera em 8s,
   vagueia devagar pela arena. Ataque direto segue inofensivo (projétil não colide
   com Area3D) — exatamente a regra do original.

5. **ARQUITETURA — arena.gd god-file (1489 linhas)**: ~1100 linhas de testes/demos
   misturadas à produção. Correção: extraídas para `scripts/dev_arena.gd` sem mudança
   de comportamento; arena.gd ficou ~330 linhas só de produção.

## Abertos / a observar

- `WARNING: ObjectDB instances leaked at exit` na suíte headless (nós de teste sem
  free no quit — cosmético, só no --teste). Investigar com `--verbose` numa fatia calma.
- `chao_tile*.png` não têm `.import` (carregados via Image.load em runtime pela arena)
  — funciona no dev e o código tem fallback, mas no export essas texturas não entram
  no PCK a menos que sejam importadas ou adicionadas como non-resource export filter.
- Feel de movimento/knockback precisa de PLAYTEST humano (não valida em headless).
