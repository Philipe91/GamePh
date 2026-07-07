# Plano Noturno 2 — "acordar com um jogo top" (2026-07-07)

Pedido do humano: sessão longa autônoma. Pesquisar sempre (fidelidade ao Trap Gunner),
armas reais por personagem, texturas, sangue/feedback de dano, IA mais inteligente,
pontes com volume, fogo, tiros reais. Regras: fatia por vez, suíte verde + captura +
commit + DevLog a cada fatia. Prints proativos pro celular.

## Fatias (ordem por impacto)
0. PESQUISA: FAQ/manual do Trap Gunner — armas por personagem, comportamento, itens.
1. ARMAS REAIS por personagem (specs no .tres): pistola, shotgun (leque de pellets),
   handgun rápida, míssil teleguiado, lâminas, soco-foguete. Projéteis com COR, LUZ
   e trail (tiro de verdade, não bolinha branca).
2. SANGUE/HIT: burst de partículas vermelhas + flash branco no modelo ao tomar dano;
   faíscas em acerto de projétil.
3. IA INTELIGENTE: usa o LOADOUT do personagem (não kit fixo); combo assinatura
   bomba+detonador (planta e ACIONA quando o player entra no raio); mina no CAMINHO
   previsto do player (posição+velocidade); evita gás ativo e Spark Bit.
4. TEXTURAS (ambientCG CC0): chão (metal), paredes, caixas (madeira/metal).
5. PONTES com volume (plataforma+corrimão) e ESTEIRAS com direção visível.
6. FOGO residual pós-explosão (chamas no tile ~1s).
7. SFX sintetizados de verdade (ruído+envelope: explosão grave, tiro seco, hit) no
   lugar dos beeps senoidais; suporte a .wav mantido.
8. RETRATOS (PNGs oficiais do pack KayKit) na HUD e na tela de seleção.
9. Animações de morte/vitória no fim de round (os modelos já têm).
10. Se sobrar: polimento de menus, mais um mapa temático.

## Critérios (de cada fatia)
- Suíte `--teste` verde. Captura `--demo-*` conferida por mim. Commit local. DevLog.
- Fidelidade: em dúvida de spec, consultar FAQ/manual ANTES de inventar.
