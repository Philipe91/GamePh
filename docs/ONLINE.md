# VAULTBREAKER — Online (Fase 8): doc de design

> ⚠ **Fora do escopo do trabalho autônomo.** Online envolve infraestrutura, custo e
> decisões de produto que são do humano. Este documento é só o plano pra quando você
> decidir encarar — nada aqui está implementado.

## Estado atual (o que já ajuda o online)

O jogo já está bem posicionado pra netcode porque:
- Estado de partida centralizado em **autoloads** (`GameManager`, `GridManager`).
- Combatentes herdam de `Combatente` por caminho; **input do Player já é parametrizável
  por dispositivo** (`jogador_num`, helpers `_tecla/_botao/_eixo`) — fácil trocar a fonte
  do input por um pacote de rede.
- Comunicação por **signals** e grupos, com baixo acoplamento.
- Ações já passam por métodos discretos (`plantar`, `atirar`, `socar`, `iniciar_carga_unit`,
  `inserir_botao`, `ativar_caution`) — bons candidatos a virar RPCs.

## Abordagem recomendada (MVP online)

1. **Transporte:** `ENetMultiplayerPeer` (nativo do Godot 4, UDP confiável/não-confiável).
   Modelo **host-autoritativo** (um jogador hospeda; o outro conecta por IP/lobby).
2. **Sincronização:** começar com `MultiplayerSynchronizer` pra posição/rotação/healer dos
   combatentes e `@rpc` pras ações discretas (plantar/atirar/desarme/Unit). O host é a
   verdade; o cliente manda intenção, o host valida (anti-cheat básico).
3. **Determinismo do que importa:** armadilhas e dano já rodam por método central — manter
   a resolução no host e replicar o resultado (não confiar no cliente).
4. **Lobby/matchmaking:** fase 2 do online. MVP pode ser **conectar por IP** (LAN/host
   manual) antes de um serviço de salas.

## Decisões que dependem de você (humano)

- **Topologia:** host-autoritativo (mais simples, recomendado) vs. servidor dedicado
  (mais caro, melhor anti-cheat/escala).
- **Custo/infra:** servidor dedicado e relay (pra NAT) têm custo recorrente.
- **Rollback netcode?** Pro feel de fighting game seria ideal, mas é caro de implementar.
  Pro ritmo do VAULTBREAKER (mais tático que reflexo puro), host-autoritativo com
  interpolação provavelmente basta no MVP.

## Passos concretos quando for a hora

1. Trocar a fonte de input do Player 2 por um `MultiplayerPeer` (já é parametrizável).
2. Adicionar `MultiplayerSynchronizer` a player/bot e `@rpc` às ações.
3. Tela de "Hospedar / Conectar por IP" (reaproveitar o estilo de `titulo.tscn`).
4. Mover a resolução de dano/armadilha pra "só no host" e replicar.
5. Testar em LAN, depois NAT/relay.

Roadmap geral: `GDD.md` seção 15 (Fase 8). Estado do projeto: `PROGRESSO.md`.
