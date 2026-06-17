# GDD: VAULTBREAKER (codinome de trabalho)

Documento mestre do projeto. Serve de cérebro pro Claude Code durante todo o
desenvolvimento. Sempre que houver dúvida de escopo, regra ou arquitetura, este
arquivo é a fonte da verdade. Atualize este documento quando uma decisão mudar.

Inspiração de mecânica: Trap Gunner (Atlus, PS1, 1998). Mundo, personagens, nomes
e arte são originais. Mecânica de jogo não tem copyright, então reproduzimos o
gameplay livremente, mas nada da IP da Atlus entra no projeto.

---

## 1. Visão e pilares

Arena fighter 2.5D top-down 1v1 onde o combate não é só mira e reflexo, é leitura
do território. Você vence transformando o mapa numa teia de armadilhas enquanto
desarma a teia do inimigo, e fecha a conta com tiro, soco ou a super.

Pilares (toda decisão de design precisa respeitar pelo menos um):

1. O mapa é a arma. Posicionamento de armadilha vale mais que mira.
2. Informação é poder. Detectar e desarmar a armadilha inimiga é metade do jogo.
3. Risco e leitura. Toda armadilha que você planta pode te pegar de volta.
4. Feedback gostoso. Cada explosão, queda e knockdown precisa ter peso visual e sonoro.

---

## 2. Decisões travadas

- Engine: Godot 4.x estável (versão standard, não a .NET).
- Linguagem: GDScript tipado.
- Direção de arte: 2.5D. Modelos 3D em câmera ortográfica top-down com leve
  inclinação. Visual moderno, neon urbano, partícula pesada.
- Roster: personagens e mundo originais.
- MVP: somente local mais bot. Online fica pra camada de modernização (fase 8).
- Ferramenta de produção: Claude Code conectado ao Godot via MCP.
- Idioma do código e comentários: português.

---

## 3. Mundo e narrativa

A megacorp de logística VECTOR usa câmaras de teleporte chamadas Vaults pra
contrabandear armas e tecnologia ilegal pelas cidades. Seis operadores
independentes descobriram demais e viraram alvos. A VECTOR não consegue matá-los
de frente, então os força a se enfrentarem dentro das próprias Vaults, onde cada
arena vira um campo de extermínio cheio de armadilhas e entregas surpresa.

As Vaults são o equivalente moderno do P.O.D.S. do jogo original: pontos no mapa
que cospem itens e power ups no meio da partida.

Tom: cyberpunk urbano, concreto e neon, chuva e luz fria. Encaixa com top-down,
com partícula e com a estética que você já domina no Caos Cívico.

---

## 4. Roster original (6 personagens)

Cada personagem tem uma arma à distância e um loadout de 3 tipos de armadilha com
quantidades fixas, mais uma filosofia de jogo. Os valores abaixo são o ponto de
partida pra balanceamento e podem mudar nos playtests.

### 4.1 BRECHT, o Demolidor
- Arma: pistola automática. Poder médio, cadência média, 5 tiros por pente.
- Armadilhas: Detonador 1, Bomba 4, Mina 4.
- Filosofia: monta campos minados com bombas em volta dos detonadores e das minas
  pra multiplicar o estrago. Joga de área negada e explosão grande.
- Velocidade: média.

### 4.2 MAGNUS, o Executor
- Arma: shotgun. Poder alto, cadência lenta, espalhamento que facilita acertar.
- Armadilhas: Detonador 2, Bomba 6, Gás 2.
- Filosofia: tanque. Aguenta dano e troca de perto. Usa detonador mais bomba pra
  criar explosões enormes e manter o inimigo longe, e não tem medo de shotgun no aperto.
- Velocidade: média baixa, vida alta.

### 4.3 VESNA, a Controladora
- Arma: handgun automática. Poder médio, cadência rápida, 6 tiros.
- Armadilhas: Mina 5, Gás 1, Painel de Força 3.
- Filosofia: nega espaço com muitas minas, especialmente em volta das Vaults. Usa
  o Painel de Força pra empurrar o inimigo pra dentro da zona de perigo que ela criou.
- Velocidade: rápida.

### 4.4 PIP, a Unidade
- Arma: míssil teleguiado. Poder baixo, cadência lenta, persegue e derruba o alvo.
- Armadilhas: Detonador 3, Cova 4, Painel de Força 4.
- Filosofia: combo. Prende o inimigo na Cova e o chuta pra cima dos detonadores.
  Usa o míssil pra atrapalhar a tentativa de desarme do inimigo.
- Velocidade: lenta. Droid de comportamento instável, bom pra um personagem caótico.

### 4.5 KESTREL, o Corredor
- Arma: lâminas de arremesso. Poder baixo, cadência rápida, 7 lâminas.
- Armadilhas: Mina 2, Cova 3, Painel de Força 2.
- Filosofia: pressão e velocidade. Acerta um golpe forte de perto e joga o inimigo
  numa Cova ou Painel. Desarma rápido e planta armadilha na cara de quem persegue.
- Velocidade: muito rápida, vida baixa.

### 4.6 MARA, a Aberração
- Arma: soco foguete regenerativo. Poder baixo, cadência lenta, teleguiado.
- Armadilhas: Mina 3, Cova 6, Gás 2.
- Filosofia: lentidão compensada por controle total do chão. Espalha Covas por todo
  lado e fecha com Gás ou Plasma. Coloca Cova e Mina em volta de áreas críticas.
- Velocidade: lenta, arma de contato pesada.

---

## 5. Sistema de grid

Base de tudo. Sem grid, armadilha não funciona.

- Arena lógica em grade de tiles (começar 12x12, ajustável por mapa).
- `GridManager` como autoload (singleton). Responsabilidades:
  - Converter grid para mundo e mundo para grid (`grid_to_world`, `world_to_grid`).
  - Guardar ocupação de cada tile e a lista de armadilhas plantadas, com dono.
  - Validar se um tile aceita armadilha.
- Movimento do personagem é livre (CharacterBody3D), não travado em célula. O snap
  acontece só no momento de plantar a armadilha, que vai pro centro do tile mais próximo.
- Tiles onde NÃO se pode plantar armadilha:
  1. Vaults (o P.O.D.S.)
  2. Escadas
  3. Rampas
  4. Esteiras
  5. Tile que já tem outra armadilha

---

## 6. Sistema de armadilhas

São 6 tipos. As armadilhas que o personagem não possui podem ser obtidas como item
durante a partida. Quando uma armadilha é usada, ela volta pro inventário do dono
depois de um tempo (padrão 6 segundos).

Specs (tiradas do manual original, mantidas como base de balanceamento):

### Detonador (Switch Detonator)
- Efeito: dano mais explosão.
- Detonação: só explode quando o dono aperta o botão depois de plantar.
- Alcance: largo. Poder: baixo.
- Regra de combo: se houver mais de uma bomba dentro do raio do detonador,
  todas as bombas no raio explodem juntas ao acionar.

### Mina (Mine)
- Efeito: dano.
- Detonação: explode quando o inimigo pisa nela.
- Alcance: estreito. Poder: médio.
- Regra: se o próprio dono estiver no raio, também toma dano.

### Bomba (Bomb)
- Efeito: dano mais empurrão.
- Detonação: só explode se acionada por um Detonador ou Mina.
- Alcance: largo. Poder: alto.
- Regra: não explode pela explosão do inimigo. Explode se estiver no raio do
  próprio Detonador ou Mina do dono. É a peça central dos combos de explosão.

### Gás (Gas)
- Efeito: dano mais imobilização de 1 segundo mais redução de velocidade pela
  metade por alguns segundos.
- Detonação: emite veneno automaticamente um tempo depois de plantado.
- Alcance: muito grande. Poder: médio.
- Regra: se o dono encostar no gás, também toma dano.

### Cova (Pitfall)
- Efeito: impede o movimento por alguns segundos.
- Detonação: dispara quando o inimigo pisa.
- Alcance: só o tile onde foi plantada.
- Regra: quem cai pode apertar vários botões pra sair mais rápido.

### Painel de Força (Force Panel)
- Efeito: arremessa o inimigo numa direção.
- Detonação: dispara quando o inimigo pisa.
- Alcance: só o tile onde foi plantado.
- Regra: a direção do arremesso é definida pela direção que o dono está olhando no
  momento de plantar. Segurar o botão de plantar e usar o direcional muda a direção.

### 6.1 Caution Mode (modo de busca de armadilha)
- Segurar um botão entra no Caution Mode, também chamado de Trap Search Mode.
- Os tiles dentro do alcance ficam destacados em azul.
- Se a armadilha inimiga está nesse alcance, um marcador aparece sobre ela.
- É possível andar dentro do Caution Mode segurando o botão e usando o direcional.

### 6.2 Desarme
- Pra desarmar, primeiro encoste na armadilha inimiga dentro do Caution Mode, o que
  cancela o gatilho dela.
- Aparece uma sequência de botões a inserir dentro de um tempo limite (o Disarming Code).
- Se o tempo zerar ou o código sair errado, a armadilha detona ou ativa.
- Se você levar um tiro ou golpe durante o desarme, a armadilha detona automaticamente.
- Desarme com sucesso: o inimigo perde a armadilha e o Healer do desarmador sobe um pouco.

### 6.3 Retomar a própria armadilha
- Ao encostar na própria armadilha dentro do Caution Mode, é possível recolhê-la.
- O jogo pergunta se quer retomar. Confirmar devolve a armadilha pro estoque.

---

## 7. Combate

### 7.1 Ataque à distância (projétil)
- Cada personagem tem uma arma de projétil com munição e recarga.
- Quando a munição zera, recarrega. Recarregar deixa o personagem vulnerável.
- Recarga é ilimitada em número de vezes.
- Algumas armas (míssil, soco foguete) são teleguiadas e derrubam o alvo.

### 7.2 Corpo a corpo (knockdown)
- Quando o inimigo está perto, soco ou chute.
- Qualquer acerto derruba o inimigo.
- Se o inimigo estava carregando a Unit (Plasma) ao ser derrubado, o lançador quebra.
- Inimigo derrubado pode tomar dano massivo da Unit.

### 7.3 Healer e condição de vitória
- Healer é a barra de vida. Começa cheia.
- Perde a partida quem tem o Healer totalmente esvaziado dentro do tempo limite.
- Se ninguém esvaziar dentro do tempo, vence quem tomou menos dano.
- Tempo limite padrão do MVP: 90 segundos.
- Quando faltam 30 segundos, surge um Spark Bit no mapa (forma viva de eletricidade
  que dá dano ao toque), pra forçar ação.

---

## 8. Vaults (P.O.D.S.) e itens

- Vault é o ponto do mapa que cospe itens e power ups durante a partida.
- Não se pode plantar armadilha em cima da Vault.
- Tipos de item:
  - Item de Armadilha: adiciona uma armadilha ao inventário.
  - Speed Up: dobra a velocidade por 20 segundos.
  - Protect: invencível por 8 segundos contra ataques diretos e armadilhas, mas
    NÃO protege contra a Plasma da Unit.
  - Unit: arma experimental de Plasma (ver seção 9).
  - Healer: recupera parte da vida.
- Caixas destrutíveis (Obstacle Box) também podem soltar itens escondidos ao serem destruídas.

---

## 9. Unit (Plasma), a super

- Arma experimental de Plasma teleguiada. É o "super" do jogo.
- O lançador é frágil e quebra se o dono for derrubado.
- O número de Plasma Bombs é limitado e a carga demora.
- Se o dono for atacado durante a carga, a Plasma não dispara.
- Como evitar a Plasma do inimigo:
  1. Correr até ela sumir (em área aberta, correr em círculo).
  2. Passar embaixo de ponte ou passarela (a Plasma destrói a ponte ao acertar).
  3. Atirar no inimigo durante a carga pra interromper, ou derrubá-lo no corpo a corpo.
  4. Provocar uma explosão no caminho dela (a Plasma some ao colidir com explosão).

---

## 10. Field Traps (armadilhas de mapa)

Alguns mapas têm armadilhas fixas que são obstáculos:

- Obstacle Box: caixa destrutível, pode soltar item escondido.
- Bomb Box: caixa que explode ao ser destruída e detona bombas em volta.
- Laser Launcher: dispara lasers em intervalos. Destrutível por projétil ou bomba.
- Rocket Launcher: dispara foguetes em intervalos. Destrutível por projétil ou bomba.
- Spark Bit: eletricidade viva, dá dano ao toque, regenera com o tempo, só morre com
  bomba (ataque direto não destrói). Aparece sozinho quando faltam 30s.
- Esteira (Conveyer Belt): muda a velocidade e direção do personagem. Não aceita armadilha.

---

## 11. Câmera, HUD e radar

### Câmera
- Camera3D ortográfica, top-down com inclinação de cerca de 60 graus pro look 2.5D.
- Moderna: zoom suave, acompanhamento leve, screenshake em explosões.
- Opção de mudar ângulo (3 tipos no original: Normal, Quarter, Top).

### HUD
- Healer do player e do oponente.
- Timer da partida.
- Ícone de seleção de armadilha e contador do inventário.
- Munição restante.
- Radar com cores:
  - Azul: jogador 1.
  - Vermelho: jogador 2.
  - Verde: Vault (pisca quando há item disponível).
  - Amarelo: Field Trap e armadilha detectada.
  - Azul claro: pontes e passarelas.

---

## 12. Modos de jogo

- MVP: VS COM (contra bot) local e VS MAN (contra humano) local em tela dividida.
- Story Mode: campanha de um personagem até o chefe da VECTOR. Algumas missões não
  são matar o oponente, são desarmar todas as armadilhas e obstáculos da fase.
- Camada futura: online, ranqueado, progressão.

---

## 13. Camada de modernização (o que faz melhor que 98)

- Juice pesado: screenshake, partícula, flash no hit, peso de impacto.
- Netcode online na fase 8.
- Câmera moderna com zoom e rotação suaves.
- Bot com IA real de posicionamento de armadilha, não só Easy, Normal, Hard.
- Combos e sinergias de armadilha novas além do detonador mais bomba.
- Progressão roguelite e unlocks entre partidas.
- Export pra mobile (Godot exporta).

---

## 14. Arquitetura técnica

### Estrutura de pastas sugerida
```
res://
  autoloads/        # GridManager, GameManager, AudioManager
  scenes/
    arena/          # cenas de mapa
    characters/     # cena base de personagem e variações
    traps/          # uma cena por tipo de armadilha
    items/          # itens da Vault
    ui/             # HUD, menus, radar
  scripts/          # scripts soltos e classes base
  assets/
    models/         # modelos 3D
    sprites/        # texturas e ícones
    audio/          # sfx e música
  resources/        # Resources de stats de personagem e armadilha (.tres)
```

### Padrões
- Stats de personagem e de armadilha como `Resource` customizado (.tres), pra
  balancear sem mexer em código.
- Autoloads pra estado global: GridManager (grid e armadilhas), GameManager (placar,
  tempo, condição de vitória), AudioManager.
- Comunicação por signals, não por referência direta forte entre nós.
- GDScript tipado sempre que possível.
- Uma cena por tipo de armadilha, instanciada pelo GridManager.

---

## 15. Roadmap por fases

A regra de ouro: a Fase 2 é o que importa. Se o vertical slice for divertido, o
resto é execução. Não pule pra arte fina antes do loop estar gostoso.

### Fase 1: Setup
- Godot 4.x, MCP conectado ao Claude Code, repo, esqueleto do projeto.
- Pronto quando: o agente lista a árvore de cena pelo MCP e roda o projeto.

### Fase 2: Vertical slice
- 1 personagem (cápsula placeholder), movimento livre, câmera top-down 2.5D.
- Grid 12x12, GridManager, Healer, vitória por depleção em 90s.
- Só a Mina como armadilha (inventário 4, retorno em 6s).
- Bot que persegue em linha e pode pisar nas minas.
- HUD básico: dois Healers, timer, contador de minas.
- Pronto quando: dá pra ganhar uma partida plantando minas contra o bot, e é divertido.

### Fase 3: Sistema completo de armadilhas
- As 6 armadilhas com specs da seção 6.
- Caution Mode, desarme com Disarming Code, retomada.
- Pronto quando: dá pra plantar, detectar, desarmar e retomar qualquer armadilha.

### Fase 4: Combate completo
- Projétil com munição e recarga, corpo a corpo com knockdown.
- Unit/Plasma com carga e as 4 formas de evasão.
- Itens da Vault.
- Pronto quando: o loop de combate completo funciona com a Unit.

### Fase 5: Roster
- Os 6 personagens com stats, armas e loadouts da seção 4, via Resources.
- Pronto quando: dá pra escolher entre os 6 e cada um joga diferente.

### Fase 6: Arenas e field traps
- Múltiplos mapas com variantes de Vault e Field Trap.
- Pronto quando: pelo menos 3 mapas jogáveis com field traps funcionando.

### Fase 7: Juice, UI e modos
- Partícula, screenshake, som, menus, Story, VS COM, VS MAN.
- Pronto quando: parece um jogo, não um protótipo.

### Fase 8: Camada moderna
- Online, progressão, polish.

### Fase 9: Export
- PC primeiro, mobile depois.

---

## 16. Regras de trabalho com o Claude Code e o MCP

Pra evitar o agente criar muitos arquivos quebrados de uma vez (lição do limite de
payload):

1. Trabalhe uma fatia por vez. Ao terminar uma parte, rode o jogo e mostre o
   resultado por screenshot antes de seguir.
2. Crie cenas e scripts pelo MCP, não cole código gigante no chat.
3. GDScript tipado e comentado em português.
4. Mantenha este GDD aberto e atualizado. Decisão nova, atualiza aqui.
5. Imagens e assets pesados: salve no projeto e referencie por caminho, nunca
   anexe binário grande no chat.
6. Nunca cole chaves de API no chat. Use .env ou variáveis de ambiente.

---

## 17. Glossário (original para o nosso mundo)

- P.O.D.S. vira Vault.
- Healer vira a barra de vida (mantemos o conceito, nome interno pode ser HP).
- Unit vira a super de Plasma (mantemos a mecânica).
- GAIN vira VECTOR.
- Os 6 personagens da Atlus viram Brecht, Magnus, Vesna, Pip, Kestrel e Mara.

Mecânica é livre, identidade é nossa.
