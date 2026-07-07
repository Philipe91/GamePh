# BRIEFING — Tirar o VAULTBREAKER do look protótipo
**2026-07-07 · Escrito a partir do playtest do Philipe (screenshot da arena SETOR 01)**

> **Para o agente (Claude Code):** este documento é a ordem de trabalho do próximo
> passe visual. Leia junto com `ART_BIBLE_VAULTBREAKER.md` (a lei) e
> `docs/PESQUISA_ASSETS.md` (as fontes). Execute NA ORDEM da seção 3, uma fatia
> por vez, com screenshot de antes/depois a cada etapa (regra 1 do CLAUDE.md).

---

## 1. Diagnóstico do print atual (por que parece protótipo)

O jogo está mecanicamente completo, mas a screenshot revela 5 problemas de
direção de arte — nenhum exige asset novo, quase tudo é material/luz/ajuste:

1. **Personagem errado da família.** Em cena está o operário de colete laranja
   (NPC civil do pack Quaternius). O elenco deve usar os modelos adultos com
   recolor tático da Art Bible §3: traje escuro dessaturado + acentos EMISSIVOS
   na cor do time (azul P1 / vermelho P2). Regra: ambiente ≤35% saturação,
   personagens/perigos ≥70%.
2. **Chão xadrez de alto contraste = arcade.** Dois tons de azul alternados
   gritam "protótipo". O alvo é placa metálica quase uniforme (variação sutil
   entre tiles, ~10–15% de valor, não 50%), com sujeira, desgaste e decalques.
   A textura `assets/sprites/texturas/MetalPlates006_*` (ambientCG, CC0, já no
   projeto com albedo+normal+roughness+metalness) deve dominar o piso.
3. **Iluminação achatada.** Tudo meio-iluminado de azul, sem hierarquia. Aplicar
   a escada de brilho IMUTÁVEL da Art Bible §2: centro do tabuleiro aceso como
   ringue > bordas ~30% mais escuras > moldura industrial em meia-luz > horizonte
   em silhueta + fog baixo. WorldEnvironment com fog volumétrico leve + glow.
4. **Props incoerentes e soltos.** Caixotes de madeira (textura Planks) num
   complexo cyberpunk, alguns flutuando. Trocar por containers/máquinas do
   Modular Sci-Fi MegaKit / Cyberpunk Game Kit (Quaternius, CC0), ancorados no
   chão (sombra de contato / decal de oclusão).
5. **HUD de debug.** Fonte padrão do Godot + retratos genéricos. Adotar uma
   fonte display industrial (ver §2.3) e molduras na linguagem burocrática
   VECTOR — a mesma das placas "SETOR 01", que já estão certas.

---

## 2. Fontes de assets aprovadas (grátis, licença verificada)

### 2.1 Texturas PBR — prioridade desta ordem
| Fonte | Licença | Uso |
|---|---|---|
| **ambientCG** — ambientcg.com | CC0 | PRINCIPAL. Metal Plates, Concrete, Paint (faixas amarelas), Rubber. Baixar 1K JPG (padrão já usado no projeto) |
| **Poly Haven** — polyhaven.com | CC0 | Complemento: texturas + HDRI para iluminação ambiente |
| **Fab giveaways (Epic)** — fab.com | Fab Standard (permite Godot e uso comercial) | OPORTUNISTA: 3 assets grátis a cada 2 semanas. O humano gostou das texturas daí. ATENÇÃO: verificar formato — só baixar se vier fonte (PNG/EXR ou FBX/glTF); listing só-`.uasset` NÃO serve no Godot |

Regra: texturas do Fab são bônus quando aparecerem — a espinha dorsal é
ambientCG/Poly Haven (CC0, sem cadastro de licença por item, sempre disponível).
O humano baixa os arquivos (o agente não gera/baixa binários); o agente pede o
material exato com nome e link e depois pluga.

### 2.2 Modelos — família única (decisão fechada em PESQUISA_ASSETS.md)
- **Elenco:** Quaternius Ultimate Modular Men + Women (CC0) — JÁ no projeto.
  Falta recolor tático + emissivos por personagem (Art Bible §3).
- **Animações:** Quaternius Universal Animation Library 1+2 (CC0, versão Godot
  pronta) — retarget sobre o rig do elenco.
- **Cenário:** Quaternius Modular Sci-Fi MegaKit + Cyberpunk Game Kit (CC0).
- **PROIBIDO:** misturar famílias de personagens em cena (pilar da Art Bible).
  Kenney/KayKit para personagem = vetado. Sketchfab avulso = vetado.

### 2.3 Garimpo itch.io (varredura 2026-07-07 — grátis, verificado)
| Asset | Autor | Licença | Uso no VAULTBREAKER |
|---|---|---|---|
| **Free Sci-Fi PBR Texture Pack Vol 1–3** — lumyx.itch.io | Lumyx | grátis pessoal+comercial | ★ MELHOR ACHADO: PBR 4K seamless (Color/Normal/Rough/Metal/AO/Height), painéis tech e pisos — paredes da moldura industrial e variações do tabuleiro |
| **369 Seamless Synthetic Textures / Tiny Texture Packs** — screamingbrainstudios.itch.io | Screaming Brain | CC0 | banco de texturas de apoio (metais enferrujados, sintéticos) |
| **Free Music Pack (43 faixas)** — clement-panchout.itch.io | Clément Panchout | grátis c/ crédito | trilha placeholder digna (o jogo hoje só tem beeps) |
| **PSX Style Cars** — ggbot.itch.io | GGBotNet | CC0 | veículos de fundo/estacionamento na moldura (recolor na paleta) |
| Universal Animation Library 1+2, Modular Sci-Fi MegaKit — quaternius.itch.io | Quaternius | CC0 | já decidido (§2.2) — os mesmos packs também estão no itch |

Descartados na varredura: personagens do itch (267 resultados = voxel/PSX/esqueleto/
medieval — nada adulto-tático coeso); JustCreate3D Cyberpunk City (é PAGO, US$ 9,99+);
KayKit Space Base Bits (estilo arredondado conflita com a Art Bible).

### 2.4 Fonte e ícones
- Fonte display industrial grátis (ex.: "Industry"-like no Google Fonts:
  **Saira Condensed**, **Rajdhani** ou **Chakra Petch** — licença OFL) para HUD
  e sinalização. Fonte mono (ex.: **JetBrains Mono**) para códigos de desarme.
- Ícones: manter os decalques próprios das armadilhas (já certos).

---

## 3. Ordem de execução (uma fatia por vez, print a cada etapa)

A luz vem primeiro porque muda a leitura de todo o resto — não ajuste material
antes de fechar a luz.

1. **LUZ.** WorldEnvironment: fog volumétrico baixo, glow calibrado, ambiente
   escuro. SpotLights "holofotes de ringue" sobre o tabuleiro (improviso
   clandestino: presos nas vigas, Art Bible §1). Bordas do campo ~30% mais
   escuras que o centro. Validar a escada de brilho com print.
2. **CHÃO.** Matar o xadrez: MetalPlates006 dominante, variação sutil por tile
   (2ª variante de material, não 2 cores), juntas escuras entre placas, decalques
   de desgaste/óleo/números de setor. Faixas amarelas de manutenção no perímetro.
3. **PERSONAGENS.** Substituir o operário laranja: modelos táticos do elenco,
   recolor escuro + máscara emissiva na cor do time, rim light fresnel (já
   implementado) conferido contra o fundo novo.
4. **PROPS.** Containers/máquinas sci-fi no lugar dos caixotes de madeira;
   tudo ancorado (y=0, sombra de contato). Moldura industrial nas bordas da
   câmera (clamp nunca mostra vazio — Art Bible §2).
5. **HUD.** Fonte nova, molduras VECTOR, retratos do elenco real (viewport
   capture dos modelos recoloridos serve como placeholder digno).
6. **VALIDAR.** Suíte `--teste` verde (99/99) + capturas dos 3 mapas + captura
   final comparada com o print do diagnóstico.

Critério de pronto: uma screenshot nova, lado a lado com a antiga, em que os 4
elementos da assinatura visual (tabuleiro aceso, duelo azul×vermelho, LEDs
pulsando, mundo vivo ao fundo) existam de verdade.

---

## 4. Referência do humano
O Philipe vai fornecer uma imagem de como imagina o resultado. Quando ela chegar,
salvar em `docs/referencias/` e calibrar paleta/mood contra ela ANTES da etapa 1.
Até lá, a referência é a Art Bible.
