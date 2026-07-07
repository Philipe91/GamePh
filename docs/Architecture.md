# Architecture — VAULTBREAKER (remake Trap Gunner)

Atualizado: 2026-07-06. Godot 4.6.3, GDScript tipado, código em português.

## Visão geral

```
autoloads/  (estado global, comunicação por signals)
  grid_manager.gd   Grid lógico: grid<->mundo, ocupação, armadilhas com dono, tipos de tile
  game_manager.gd   Partida: rounds (Bo3), relógio 90s, placar, vitória, hit_stop (juice)
  audio_manager.gd  SFX por nome de evento (pool de 8 players, pitch aleatório ±8%)
  persistencia.gd   ConfigFile em user:// (settings + vitórias/derrotas)

scenes/
  arena/arena.gd        SÓ produção: monta mapa (.tres), Vaults, field traps, estruturas
                        3D (mapas verticais), reset de round, câmera-segue, oclusão de pontes
  arena/camera_tremor.gd Screenshake por OFFSET composável (não briga com câmera-segue)
  arena/explosao_fx.*   Partículas one-shot + OmniLight com fade (flash da explosão)
  characters/combatente.gd  BASE (Player e Bot herdam por caminho): Healer, dano, knockback
                        por IMPULSO físico (decai, respeita colisão), status (slow/imobiliza/
                        speed/protect), arma (munição/recarga), soco/knockdown, Unit/Plasma
  characters/player.gd  Input (teclado+gamepad, 2 jogadores), plantio c/ snap, Caution Mode,
                        Desarme (código de setas), Retomada, menu radial
  characters/bot.gd     IA: persegue, kite c/ pouca vida, desvia de armadilhas, planta
                        situacional (mina território de Vault / cova perto / mina longe),
                        desarma, busca itens, usa Unit, dificuldade (facil/normal/dificil)
  traps/armadilha.gd    GENÉRICA: ramifica pelas 6 armadilhas via StatsArmadilha (.tres)
  projeteis/            projetil.gd (reto ou teleguiado/Cannon), plasma.gd (super, evasões)
  items/                vault.gd (P.O.D.S., sorteio por peso), item.gd (5 tipos),
                        spark_bit.gd (vagueia, morre só com explosão, regenera)
  field_traps/          caixa (obstacle/bomb box), esteira, lancador (laser/cannon), ponte
  ui/                   hud.gd (barras animadas, timer, desarme, placar), radial_menu.gd,
                        radar.gd, titulo/selecao/settings/story/pausa, ui_estilo.gd

scripts/
  stats_armadilha.gd / stats_personagem.gd / stats_mapa.gd   Resources de balanceamento
  dev_arena.gd          Suíte de testes headless (--teste) + demos de captura (--demo-*)
                        EXTRAÍDA de arena.gd (que tinha 1489 linhas; hoje ~330)

resources/  .tres de armadilhas (6), personagens (6), mapas (5)
```

## Padrões e decisões

- **Dados em Resource (.tres)**: armadilhas, personagens e mapas balanceiam sem código.
- **Acoplamento solto**: grupos (`combatentes`, `armadilhas`, `itens`, `destrutiveis`,
  `pontes`, `vaults`, `explosoes`, `fx`, `camera`) + `has_method` + signals. Nenhuma
  referência por nome de nó entre sistemas.
- **Herança por caminho** (`extends "res://..."`), não por class_name — resolve headless
  sem cache de classes do editor.
- **Visual gravado no .tscn** (aparece no editor); só o dinâmico é montado por código.
- **Knockback = impulso**: `Combatente._impulso` decai exponencialmente (λ=8/s) e entra
  no `move_and_slide` das subclasses — distância total ≈ `forca`. Sem teleporte.
- **Hit stop**: `GameManager.hit_stop(escala, dur)` com timer de tempo real; não empilha.
- **Screenshake**: offset aplicado e removido por frame (compõe com câmera-segue).
- **Testes**: `--teste` roda a suíte inteira headless (dev_arena.gd), imprime OK/FALHOU
  por asserção e encerra. Rodar sempre antes de commitar.

## Fluxo de uma partida

titulo.tscn → selecao.tscn (personagem+mapa → GameManager) → arena.tscn:
`_ready` carrega o StatsMapa → GridManager.configurar_mapa → spawns/Vaults/field traps →
`GameManager.iniciar_partida([p1, p2])`. Rounds: `round_comecou` → arena reseta;
`healer_zerou`/tempo → `round_acabou` → 2 vitórias → `partida_acabou` → HUD/rematch.

## Dívidas conhecidas

Ver `docs/BugReport.md` e Roadmap. Principais: arte/som placeholders (cápsulas/beeps),
personagens sem modelos próprios/animações, Story Mode esqueleto, online não iniciado.
