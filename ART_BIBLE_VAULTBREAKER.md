# ART BIBLE — VAULTBREAKER
**Sucessor espiritual de Trap Gunner · padrão visual 2024–2026 · v1.0 (2026-07-07)**

Este documento governa TODA decisão visual do projeto. Nada entra no jogo sem passar
pelo teste de cada seção. Decisões anteriores que conflitem com este documento são
descartadas.

---

## 1. Visão artística (uma frase)

> **"Um torneio clandestino de especialistas em armadilhas, disputado nos setores de
> um mega-complexo industrial subterrâneo da VECTOR — visto de cima, lido em um
> relance, iluminado como um thriller."**

### Os 4 pilares (ordem de prioridade)
1. **LEITURA ACIMA DE TUDO** — é um jogo tático de grid. Personagem, armadilha, item
   e perigo se distinguem em <0,5s a qualquer momento. Atmosfera nunca compra briga
   com gameplay (lição de Battlerite/Advance Wars: arena limpa, bordas ricas).
2. **O LUGAR EXISTE** — a arena é uma SALA dentro de um prédio, nunca uma plataforma
   flutuando no vazio. Toda borda de tela mostra arquitetura: parede, duto, viga,
   andar ao fundo. (The Ascent/Ruiner: densidade industrial na moldura.)
3. **UMA FÁBRICA, UM ESTÚDIO** — todos os assets da mesma família de formas: low-poly
   facetado com materiais sólidos + PBR sutil. Se um objeto parece "de outro jogo",
   ele sai ou é re-material izado.
4. **PERIGO É LINDO** — armadilhas, explosões e a Unit são os objetos mais bonitos e
   luminosos do jogo (Trap Gunner: a armadilha é a estrela).

---

## 2. Universo

**O Complexo VECTOR**: um mega-complexo subterrâneo de P&D militar-industrial.
A megacorp VECTOR transformou setores desativados em arenas do torneio VAULTBREAKER.
Cada mapa é um **setor** com função crível — máquinas, sinalização e iluminação
contam o que aquele lugar fazia antes de virar arena.

### Mapeamento dos 6 mapas → setores (mantém layouts/gameplay intactos)
| Mapa (.tres) | Setor | História visual | Acento |
|---|---|---|---|
| Padrão | **SETOR 01 — Piso de Treinamento** | ginásio de certificação da VECTOR, sinalização didática | azul-aço |
| Porto | **DOCA 04 — Cais de Carga** | containers, guindastes, empilhadeiras paradas | teal |
| Corredor | **CONDUTO 09 — Galeria de Serviço** | corredor técnico longo, tubulação nas duas paredes | âmbar |
| Fortaleza | **COFRE 12 — Antecâmara do Vault** | segurança máxima, portas blindadas, roxo institucional | roxo |
| Cruz Vertical | **NÚCLEO 06 — Poço de Ventilação** | passarelas cruzadas sobre um poço, ar em movimento | ciano frio |
| Setor 07 | **REATOR 07 — Sala da Usina** | maquinário pesado, aviso amarelo/preto, vapor | laranja industrial |

---

## 3. Arquitetura e ambiente (mata o "vazio preto" — Missão 05)

### Regra das 3 camadas de profundidade
Toda arena tem, de dentro pra fora:
1. **CAMPO** (jogável): chão de placas + obstáculos funcionais. Contraste alto,
   silhuetas limpas, NADA decorativo dentro do grid.
2. **MOLDURA** (2–6m além das paredes): passarelas, dutos, pilares, painéis,
   máquinas encostadas, luzes de manutenção. Decoração densa, mas escurecida ~40%
   vs o campo.
3. **HORIZONTE** (6m+): paredes distantes do "prédio", vigas superiores, andares de
   fundo com janelas acesas, fog azulado engolindo o resto. NUNCA preto puro — o
   fundo é sempre arquitetura + névoa.
   
Teto: implícito por VIGAS superiores cruzando o alto da tela nas bordas (não teto
sólido — a câmera é top-down; vigas + cabos pendurados vendem o interior sem ocluir).

### Chão (o maior delator de protótipo)
- Base: placas metálicas PBR (já em uso) **+ camada de identidade**: faixas de
  segurança amarelo/preto no perímetro, numeração de setor estampada em tiles-chave,
  linhas-guia na cor do acento, manchas de desgaste/óleo (decal escuro alfa baixo),
  grades de ventilação em tiles aleatórios fixos por seed.
- O xadrez de duas cores CONTINUA (leitura de grid é pilar 1), mas com Δ de valor
  reduzido e a "informação industrial" por cima.

### Obstáculos (nunca mais cubos)
| Hoje | Vira |
|---|---|
| Caixa de madeira | **Contêiner de suprimentos VECTOR** (caixa metálica com painel, quinas reforçadas — base atual evolui) |
| Bomb Box vermelha | **Barril de célula volátil** (cilindro com faixas de perigo + LED) |
| Mesa azul (ponte) | **Passarela de manutenção** (deck de grade + corrimãos + suportes) |
| Faixa listrada (esteira) | **Esteira transportadora real** (rolos, laterais metálicas, setas de fluxo animadas) |
| Torreta (atual ok) | mantém, ganha cabos no chão |
| Vault POD (atual ok) | mantém, ganha vapor leve ao abrir |

---

## 4. Paleta de cores

### Master (todas as cenas)
| Papel | Cor | Uso |
|---|---|---|
| Base escura | `#0B0F1A` | fundo/fog/sombras — nunca #000 |
| Metal frio | `#3A4254` | estruturas, paredes |
| Metal claro | `#6B7690` | superfícies iluminadas |
| Perigo | `#FFB300` amarelo + `#111` preto | faixas industriais, avisos |
| **P1** | `#4FB3FF` azul | rim, anel, HUD esquerda |
| **P2** | `#FF5A52` vermelho | rim, anel, HUD direita |
| Vault/positivo | `#35FF7E` verde | PODs, cura, confirmação |
| Unit/supremo | `#B84FFF` violeta | Plasma, super, raridade |

### Regra de saturação
Ambiente dessaturado (≤35%) · gameplay saturado (≥70%). O olho vai SEMPRE primeiro
ao que importa. (Ruined King/Battlerite fazem exatamente isso.)

---

## 5. Iluminação (cinematográfica industrial)

- **Key** quente levemente amarelada, ângulo 50–55°, sombras suaves 4K (atual, mantém).
- **Fill** azul frio fraco (atual, mantém) — vales nunca 100% pretos.
- **Práticas** (novo): cada máquina/painel da MOLDURA emite a própria luz (emissive
  baixo + OmniLight fraca a cada ~6m). Luzes de emergência VERMELHAS piscando em
  cantos de setor; VERDES fixas sobre spawns ("área segura" — leitura de The Finals).
- **Volumetria**: fog exponencial atual + `volumetric_fog` leve SÓ nos mapas Reator
  e Núcleo (vapor). Densidade nunca acima de leitura do grid.
- **Dinâmica**: explosão ilumina a sala inteira por 0,4s (flash 6.0, atual);
  tiro emite luz (atual); armadilha armada pulsa (atual).
- Bloom moderado threshold 1.1 (atual) — NUNCA "liguei o glow em tudo".

---

## 6. Materiais e shaders

- **PBR em 3 tiers**: chão/paredes = trio albedo+normal+rough (ambientCG);
  props modulares = materiais sólidos Quaternius (facetado, SEM textura de cor);
  acentos = emissive unshaded. Proibido material default cinza da engine.
- **Shaders autorizados**: `rim_time.gdshader` (personagens, cor do time — em uso);
  fresnel sutil em vidros; scroll UV para esteiras/hologramas; dissolve na morte
  (fase futura). Proibido: outline grosso cartoon (conflita com direção realista-estilizada).

---

## 7. Personagens

**Família travada: Quaternius Ultimate Modular Men + Women** (CC0, proporções
humanas, mesmo rig, 24 animações). Decisão da Missão 02, reafirmada aqui após
reavaliação — ver §10 para o que foi comparado e descartado.

### Por que ainda "parecem modelos gratuitos" e o plano para consertar
O problema NÃO é a malha — é que estão com as cores DEFAULT do pack. O conserto é
**descaracterização por material** (barato, alto impacto):
1. **Recolor por personagem**: cada um ganha paleta própria alinhada ao arquétipo
   (tabela abaixo) — troca de cores dos materiais sólidos, sem retexturizar.
2. **Detalhe emissivo**: 1–2 acentos LED por personagem (visor, ombreira, cinto) na
   cor pessoal — assinatura de silhueta noturna.
3. **Arma no osso da mão** (BoneAttachment3D) + muzzle point — encerra o "flutuando".
4. Silhueta já é distinta por modelo (capacete/moicano/traje espacial/elmo SWAT);
   escala por arquétipo já implementada.

| Personagem | Modelo | Arquétipo | Paleta pessoal |
|---|---|---|---|
| BRECHT | Worker | engenheiro demolidor | laranja segurança + grafite |
| MAGNUS | Swat | mercenário pesado | cinza-chumbo + vermelho escuro |
| VESNA | SciFi (F) | cientista de combate | branco-lab + verde ácido |
| PIP | Spacesuit | soldado futurista | oliva + âmbar |
| KESTREL | Punk (F) | assassina urbana | preto + violeta |
| MARA | Soldier (F) | operadora tática | verde-militar + magenta |

**Proibido para sempre**: chibi, cabeçudo, cartoon infantil, mistura de packs de
artistas diferentes no elenco.

### Retratos
Gerados por render dos PRÓPRIOS modelos (`--retratos`): mesmo enquadramento 3/4,
mesma luz de estúdio, fundo degradê na cor pessoal. Regenerar a cada mudança de
material. Nunca arte externa.

### Animações (mapeamento travado)
Idle=`Idle_Gun` · mover=`Run` · tiro=`Idle_Gun_Shoot` · plantar=`Interact` ·
soco=`Punch_Right` · hit=`HitRecieve` · morte=`Death` · vitória=`Wave`.

---

## 8. VFX (linguagem: "energia contida que escapa")

- Explosão = flash + fireball + fumaça + onda torus + luz dinâmica + shake + hit-stop
  (atual — é a régua de qualidade dos demais).
- Tiro = muzzle flash + tracer com rastro + estilhaço no impacto (atual) + **cápsula
  ejetada** (novo, física simples 0,5s).
- Armadilha armada = pulso LED lento; detectada = anel de scan; desarme = faíscas
  (atual); gás = partículas volumétricas (atual) + distorção de calor (futuro).
- Ambiente = poeira no ar (partículas lentas de moldura), vapor em grelhas, fagulhas
  ocasionais de máquinas.
- Sangue: **estilizado e mínimo** — respingo curto atual está no tom; sem poças,
  sem gore (classificação: violência estilizada).

---

## 9. Interface

- Tipografia: Orbitron para display/números + **fonte de texto secundária a
  adicionar** (Inter/Exo 2, OFL) para legibilidade de corpo.
- Ícones: um único set, gerado da MESMA técnica dos retratos (render 3D dos objetos
  reais do jogo — a mina do HUD é A mina do jogo). Elimina os ícones AI 1536×1024.
- Feedback: tudo que muda anima ≤0,25s (barras já tweenam; pips já; adicionar pulso
  no retrato ao tomar dano e slide nos rounds).
- Moldura da tela: HUD ancorada em cantos com hairline na cor do time; centro da
  tela SEMPRE limpo.
- Sons de UI: tick/confirm Kenney (atual) — manter.

---

## 10. Assets — pesquisados, escolhidos, descartados

### ESCOLHIDOS (todos CC0, todos verificados)
| Asset | Fonte | Papel | Justificativa |
|---|---|---|---|
| Ultimate Modular **Men+Women** | Quaternius | elenco (6) | única família humana completa c/ rig+24 anims; CC0 |
| Ultimate Modular **Sci-Fi** (46 modelos) | Quaternius | paredes/props/máquinas da MOLDURA e obstáculos | MESMO artista do elenco = coesão automática; modular; CC0; existe conversão Godot no GitHub (Malcolmnixon) |
| MetalPlates006 PBR | ambientCG | chão/paredes | trio PBR 1K, CC0, já integrado |
| Sci-Fi/Impact/Interface Sounds | Kenney | SFX | CC0, 30 sons já mapeados por evento |
| Orbitron | Google Fonts (OFL) | display | já integrado; ganha par tipográfico |

### DESCARTADOS (e por quê — não reabrir sem motivo novo)
| Asset | Motivo |
|---|---|
| KayKit Adventurers/Skeletons | chibi/cabeçudo — banido; tema medieval errado (removido do repo) |
| Synty POLYGON | sem versão gratuita com licença limpa |
| Mixamo | exige conta Adobe; desnecessário (família já tem anims); rig incompatível com o pipeline atual |
| Sketchfab/OpenGameArt avulsos | personagens de artistas diferentes = quebra do pilar 3 |
| Kenney Sci-Fi Kit (3D) | estilo mais "brinquedo" que o Quaternius; misturar dois estilos de prop viola pilar 3 |
| Ícones AI 1536×1024 atuais | fora de spec, estilo inconsistente — substituir por renders 3D próprios |

### PESQUISA PENDENTE (aprovada em princípio, escolher na implementação)
- **Música**: 2–3 faixas eletrônico-industrial CC0/CC-BY (OpenGameArt/FMA) — critério:
  loop limpo, 100–120 BPM, sem melodia invasiva.
- **Ambiência**: hum industrial + ventilação (freesound CC0) para camada constante.

---

## 11. Ordem de execução (após aprovação desta bible)

1. **Matar o vazio** (Missão 05, maior impacto): moldura + horizonte nas arenas
   planas — paredes de prédio distantes, vigas superiores, passarelas, andares de
   fundo com janelas, fog fechando. Base: pack Sci-Fi modular.
2. **Chão com identidade**: faixas de perímetro, numeração de setor, decals de
   desgaste, grelhas.
3. **Obstáculos reais**: contêiner/barril/passarela/esteira (tabela §3).
4. **Descaracterizar elenco**: recolor por personagem + LED + arma no osso +
   retratos regenerados.
5. **Ícones próprios** (renders 3D) + par tipográfico.
6. **Áudio**: ambiência + música + cápsulas/ricochete.
7. **Práticas piscantes + volumetria** nos 2 mapas de vapor.

Cada etapa: suíte verde → captura → commit. Teste-guia permanente:
**"isso entraria numa screenshot oficial da Steam?"**

---

## 12. Referências estudadas (princípios extraídos, nunca cópia)
- **Trap Gunner**: armadilha como estrela; grid legível; split-screen de mind games.
- **Battlerite/Ruined King**: arena saturada no centro, moldura escura decorada.
- **The Ascent/Ruiner**: densidade industrial, práticas emissivas, fog urbano.
- **The Finals**: cor institucional como sinalização de gameplay.
- **MGS/Metal Gear Acid**: tom "operação séria", sinalização militar, vermelho de alerta.
- **V Rising/Ravenswatch**: leitura top-down com rim/contraste, não com outline.
