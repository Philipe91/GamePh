# ART BIBLE — VAULTBREAKER
**v2.0 · A alma do jogo · 2026-07-07**

> **"Por que alguém vai olhar uma screenshot e reconhecer o VAULTBREAKER na hora?"**
>
> Porque nenhum outro jogo mostra **dois profissionais se caçando num tabuleiro de
> luz, cravado no fundo de uma fábrica que continua viva ao redor deles.**
>
> A assinatura visual do jogo são quatro coisas juntas, sempre:
> 1. **O tabuleiro aceso** — um grid de placas metálicas banhado de luz no centro de
>    uma sala escura, como um ringue iluminado num galpão apagado.
> 2. **O duelo azul × vermelho** — dois halos de cor viva, um em cada caçador,
>    únicas cores saturadas em movimento no quadro.
> 3. **O perigo que respira** — LEDs de armadilha pulsando devagar no chão, como
>    batimentos cardíacos espalhados pelo tabuleiro.
> 4. **O mundo que não para** — além do ringue, o Complexo VECTOR segue operando:
>    janelas acesas, vapor subindo, luzes de manutenção varrendo, máquinas ao fundo.
>
> Tire qualquer um dos quatro e vira "mais um top-down". Com os quatro, é Vaultbreaker.

---

## 1. FILOSOFIA VISUAL

### O que o jogador sente ao entrar numa partida
**Que desceu onde não devia.** A partida não acontece num estádio — acontece num
setor interditado de um complexo subterrâneo, às 3 da manhã, com a produção ainda
rodando nos andares vizinhos. A sensação-alvo é a de um **duelo clandestino**: dois
especialistas contratados, um contrato, noventa segundos.

### As três emoções do cenário (nesta ordem)
1. **Opressão calma** — teto baixo implícito, vigas pesadas, ar denso de fog. O
   lugar é maior e mais antigo que você.
2. **Tensão de tabuleiro** — o chão quadriculado sob luz é convite e armadilha ao
   mesmo tempo: cada tile pode ser a sua morte. O jogador deve OLHAR para o chão
   com respeito.
3. **Fascínio pelo perigo** — as armadilhas são os objetos mais bonitos do jogo.
   Plantar uma mina tem que dar orgulho; ver o LED dela pulsando, um prazer quase
   estético. O medo do oponente é o troféu.

### A sensação do combate
**Curto, seco, definitivo.** Nada de trocação longa: o tiro é pontuação, o soco é
vírgula, a explosão é ponto final. Cada explosão deve parecer GRANDE demais para a
sala — a luz estoura nas paredes, o vapor se agita, a câmera soca. É o contraste
entre os 80 segundos de xadrez silencioso e os 2 segundos de caos que define o ritmo.

### A personalidade do universo
A VECTOR é uma megacorp **burocrática e cínica**: sinalização por toda parte
("SETOR 07", "MANUTENÇÃO NÍVEL 3", faixas amarelas), tudo etiquetado, tudo
padronizado — e mesmo assim ela aluga os próprios setores para duelos ilegais.
O universo não é pós-apocalíptico nem heroico: é **corporativo-noturno**. Limpo por
fora, podre por dentro. O humor do jogo mora nessa hipocrisia: placas de "segurança
em primeiro lugar" penduradas sobre um campo minado.

### Como o ambiente conta história sem diálogo
- **Sinalização** conta o que o setor era (números, pictogramas, faixas).
- **Desgaste** conta o que aconteceu (marcas de explosão antigas no piso, óleo,
  arranhões de empilhadeira).
- **A operação continua** conta que ninguém se importa (janelas acesas ao fundo,
  máquinas trabalhando, ninguém veio ver o duelo).
- **Improviso** conta que o torneio é clandestino (holofotes amarrados em vigas
  apontados para o ringue, cabos puxados por cima da parede).

---

## 2. DIREÇÃO CINEMATOGRÁFICA

### Câmera
- Perspectiva inclinada 54° (a "câmera de mesa de guerra") — o jogador é o
  estrategista olhando o tabuleiro, nunca um deus distante nem um ombro colado.
- Segue o jogador com inércia suave (lerp exponencial atual) e **clamp nas bordas**:
  a câmera nunca mostra "fim de mundo" — quando chega no limite, o que entra no
  quadro é a moldura industrial, não vazio.
- Shake apenas em explosão/knockdown, curto e decrescente. A câmera é invisível:
  se o jogador notar a câmera, erramos.

### Como a luz conduz o olhar
Hierarquia de brilho IMUTÁVEL (do mais claro ao mais escuro):
1. explosões e flashes (momentâneo, domina tudo)
2. LEDs de armadilha, projéteis, vault, Unit (saturados, pulsantes)
3. halos de time azul/vermelho nos personagens
4. o campo de jogo (iluminado como palco)
5. a moldura industrial (meia-luz, práticas pontuais)
6. o horizonte do complexo (silhuetas + janelas + fog)
O olho do jogador desce essa escada naturalmente: primeiro o perigo, depois o
oponente, depois o tabuleiro, e o ambiente por último — sentido, não lido.

### Como o cenário cria tensão
- **Escuridão utilizável**: os cantos do campo são ~30% mais escuros que o centro —
  plantar lá "parece" mais seguro, e o Caution Mode vira lanterna psicológica.
- **Luzes de emergência vermelhas** giram devagar nos últimos 10 segundos da
  partida (o próprio setor avisa que o tempo acaba).
- **Vapor e fog no baixo**: esconder meio-corpo à distância cria dúvida sem nunca
  esconder o grid.

### Como os efeitos reforçam o combate
Regra do "eco": todo evento forte tem 3 ecos — **luz** (ilumina a sala), **matéria**
(faíscas/fumaça/cápsulas que sobram no chão por segundos) e **câmera** (shake ou
hit-stop). Um evento sem eco parece mentira; um evento com os três parece memória.

### Como os personagens se destacam
- Rim light fresnel na cor do time (já implementado) — silhueta recortada contra
  qualquer fundo.
- Anel de time no chão — leitura tática mesmo com o corpo ocluso.
- Ambiente dessaturado ≤35%, personagens e perigos saturados ≥70%.

---

## 3. PERSONALIDADE DOS PERSONAGENS

Todos são **profissionais do submundo corporativo** — não soldados de exército, não
heróis. Gente que trabalha à noite por dinheiro. Cada visual precisa responder:
*"qual é a especialidade dele, e o que ele carrega para exercê-la?"*

Base de malha: família Quaternius Modular (proporções humanas, mesmo rig). A
identidade vem de **recolor + acentos emissivos + equipamento coerente**, padrão
"mesmo alfaiate, clientes diferentes":

| | BRECHT — o Demolidor | |
|---|---|---|
**Quem é** | ex-engenheiro de manutenção da própria VECTOR; conhece cada parafuso do complexo | 
**Visual** | macacão de trabalho laranja-segurança surrado, colete de ferramentas, capacete com lanterna, luvas grossas, joelheiras gastas | 
**Assinatura** | a lanterna do capacete acesa (LED âmbar) e bolsos visivelmente cheios |

| | MAGNUS — o Muro | |
|---|---|---|
**Quem é** | ex-segurança corporativa demitido por excesso de zelo; agora vende o zelo | 
**Visual** | colete balístico cinza-chumbo sobre uniforme preto, elmo fechado, ombreiras rígidas, botas pesadas | 
**Assinatura** | visor vermelho-escuro do elmo — a única "cara" dele é uma linha de luz |

| | VESNA — a Química | |
|---|---|---|
**Quem é** | cientista de materiais que descobriu que armadilha paga melhor que pesquisa | 
**Visual** | jaleco tático branco-lab curto sobre roupa escura, luvas de nitrila, óculos de proteção na testa, cartuchos de reagente no cinto | 
**Assinatura** | acentos verde-ácido (tubos no cinto brilham) — a cor do gás dela |

| | PIP — o Artilheiro | |
|---|---|---|
**Quem é** | ex-piloto de carga orbital; trata mísseis como encomendas | 
**Visual** | traje pressurizado oliva com mangueiras, mochila-rack de munição, botas magnéticas | 
**Assinatura** | luzes âmbar do traje piscando em sequência quando mira (checklist de lançamento) |

| | KESTREL — a Lâmina | |
|---|---|---|
**Quem é** | assassina urbana que aceita o torneio como "férias remuneradas" | 
**Visual** | jaqueta preta justa, moicano violeta, coturno, munhequeiras com lâminas, sem armadura — velocidade é a armadura | 
**Assinatura** | rastro violeta sutil quando corre; a mais escura do elenco, quase some fora do rim light |

| | MARA — o Trator | |
|---|---|---|
**Quem é** | operadora de demolição pesada; o soco-foguete era ferramenta de trabalho | 
**Visual** | uniforme verde-militar de operação, protetor de tronco, luva hidráulica GIGANTE no braço direito (assimetria = silhueta) | 
**Assinatura** | a luva emite magenta ao carregar o soco — o braço direito é a arma |

**Regra de silhueta**: cobrir a tela com um retângulo preto sobre cada personagem —
se a sombra não disser quem é (capacete+lanterna / elmo+massa / jaleco / mochila-rack
/ moicano / braço gigante), o visual está reprovado.

---

## 4. O COMPLEXO (ambiente)

**Não existem "arenas". Existe o Complexo — e o jogador vê só um pedaço dele.**

### A regra das 3 camadas (toda cena, sem exceção)
1. **O RINGUE** — o campo jogável. Limpo, aceso, legível. Só gameplay.
2. **A MOLDURA** (0–8m além das paredes) — passarelas de manutenção, dutos, pilares,
   geradores, containers, painéis, holofotes improvisados apontados pro ringue.
   Meia-luz. Aqui mora a crença de que o lugar é real.
3. **O HORIZONTE** (8m+) — as paredes verdadeiras do prédio: fachadas internas com
   fileiras de janelas acesas (a produção continua), vigas atravessando o alto,
   guindastes parados, fog engolindo o fundo. **Preto puro é proibido**: o último
   plano é sempre arquitetura + névoa.

### Causalidade obrigatória (a "regra do encanador")
Todo objeto existe POR algum motivo e LIGADO a algo: gerador tem duto que sai dele;
painel tem cabo que corre pela parede; passarela tem pilar que a sustenta; holofote
tem gambiarra de cabo que desce da viga. Objeto órfão = objeto reprovado.

### Áreas inacessíveis que devem EXISTIR visualmente
Portões de setor fechados (com número), corredores gradeados que somem no fog,
salas de controle elevadas com vidro aceso, elevador de carga parado, docas
interditadas com fita zebrada. O jogador nunca entra — mas acredita.

---

## 5. O CHÃO (o delator número 1)

O chão é o protagonista silencioso de um jogo de armadilhas. Ele precisa parecer
**usado por décadas e sinalizado por burocratas**:
- placas metálicas PBR com desgaste (atual base, mantém);
- **faixa amarela/preta contornando o perímetro** do campo;
- **numeração do setor** estampada grande em 1–2 tiles (estêncil desbotado);
- linhas-guia na cor do acento do mapa;
- manchas de óleo e marcas de explosão antigas (decals escuros, α baixo);
- grelhas de ventilação em tiles fixos por seed (vapor sutil subindo de 1–2);
- canaletas de cabo correndo pelo perímetro, POR FORA do campo.
O xadrez tático permanece — com Δ de valor menor, coberto de "vida industrial".

---

## 6. SOM — o complexo nunca dorme

Silêncio absoluto é proibido. Três camadas permanentes:
1. **Cama** (sempre): hum grave de transformador + ventilação distante (loop CC0).
2. **Pontuação** (aleatória, esparsa): vapor escapando, metal assentando, porta
   automática ao longe, rádio corporativo abafado e ininteligível.
3. **Gameplay** (atual, Kenney): tiros, explosões, passos, UI — já implementado.
Explosão "cala" a cama por 1s (ducking) — o susto ganha espaço.

## 7. COMBATE — nada pode parecer brinquedo

- Tiro: muzzle flash + tracer + estilhaço (atual) + **cápsula ejetada** quicando.
- Explosão: flash que pinta a sala + shake + hit-stop (atual) + **marca de
  queimadura persistente no tile** até o fim do round.
- Soco: hit-stop atual + poeira no impacto.
- Armadilha: pulso-batimento no LED (atual); a mina é uma jóia letal, não um botão.
- Sangue: respingo estilizado curto (atual) — impacto sem gore.

## 8. UI — o "Sistema VECTOR"

A HUD é diegética por atitude: parece o **overlay de monitoramento do próprio
complexo** observando o duelo. Cantos com hairline na cor do time, tipografia
Orbitron para números + fonte de texto secundária (OFL) para rótulos, ícones
renderizados dos objetos 3D reais do jogo (a mina do HUD É a mina do jogo — nunca
ícone de pack), micro-animações ≤0,25s em toda mudança de estado. Centro da tela
sagrado: nada além do jogo.

---

## 9. Decisões de produção (herdadas da v1, continuam valendo)

- **Família única de assets**: Quaternius Modular (Men+Women já no jogo; **Ultimate
  Modular Sci-Fi**, 46 modelos CC0 do mesmo artista, aprovado para moldura/objetos).
  Descartados e proibidos: chibi/KayKit (removido), Synty (licença), Mixamo
  (desnecessário), packs avulsos misturados, ícones AI atuais (substituir).
- **PBR ambientCG** no chão/paredes; materiais sólidos facetados nos props; emissive
  unshaded nos acentos. Shaders: rim por time (atual), scroll UV (esteiras),
  dissolve (morte, futuro). Outline cartoon proibido.
- **Paleta master**: base `#0B0F1A` · metal `#3A4254`/`#6B7690` · perigo `#FFB300`+preto
  · P1 `#4FB3FF` · P2 `#FF5A52` · vault `#35FF7E` · Unit `#B84FFF`. Ambiente ≤35%
  saturação, gameplay ≥70%.
- **Áudio**: Kenney CC0 (atual) + ambiência industrial CC0 (pesquisar em freesound/
  OpenGameArt) + 2–3 faixas eletrônico-industrial CC0/CC-BY com crédito.

## 10. Ordem de execução (pós-aprovação v2)

1. **Matar o vazio**: moldura + horizonte procedurais em todos os mapas planos
   (fachadas com janelas acesas, vigas, pilares, passarela, holofotes).
2. **Chão vivo**: faixa de perímetro, numeração de setor, decals de uso, grelhas.
3. **Objetos com causalidade**: contêiner/barril/esteira real/passarela + cabos e
   dutos conectando tudo (pack Sci-Fi).
4. **Elenco descaracterizado**: recolor por personagem + acento emissivo de
   assinatura + arma no osso + retratos regenerados.
5. **UI própria**: ícones renderizados + par tipográfico + micro-animações restantes.
6. **Som do complexo**: cama + pontuação + ducking.
7. **Cinema**: luzes de emergência no fim do tempo, volumetria nos setores de vapor.

Critério de aprovação de cada etapa: *"esta screenshot podia estar na página da
Steam do Vaultbreaker — e só do Vaultbreaker?"*
