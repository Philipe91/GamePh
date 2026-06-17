# Instruções do projeto (leia primeiro)

Este é o remake de um arena fighter 2.5D top-down de armadilhas, codinome
VAULTBREAKER. Você é o agente de desenvolvimento deste projeto via Godot MCP.

A fonte da verdade de design é o arquivo `GDD.md` na raiz. Sempre consulte o GDD
antes de implementar qualquer sistema. Se uma decisão de design não estiver no GDD,
pergunte antes de inventar.

Idioma: todo código e comentário em português.

---

## 1. Pré-requisitos (o humano instala uma vez)

Se algo abaixo não estiver instalado, oriente o humano a instalar antes de seguir:

1. **Godot 4.x estável**, versão standard (não a .NET). Baixar em godotengine.org.
2. **Node.js LTS** (necessário pro servidor MCP do Godot). Baixar em nodejs.org.
3. **Claude Code** já instalado e funcionando (é o que você está rodando).

Verifique no terminal:
```
godot --version
node --version
```

---

## 2. Setup do Godot MCP (uma vez)

O servidor MCP é o que te dá controle do editor do Godot (criar cenas, escrever
scripts, rodar o jogo, ler erros, tirar screenshot). Passos no PowerShell, na pasta
onde o humano guarda os repositórios:

```powershell
# Clonar e buildar o servidor MCP (open source)
git clone https://github.com/ee0pdt/godot-mcp.git
cd godot-mcp/server
npm install
npm run build
```

Depois, conectar o servidor a ESTE projeto, com escopo de projeto (gera o
`.mcp.json` na raiz, versionável):

```powershell
# Rode na raiz do projeto do jogo, não dentro do Claude Code
claude mcp add godot-mcp --scope project -- node "C:\caminho\completo\godot-mcp\server\dist\index.js"
```

Troque o caminho pelo absoluto da máquina. Use caminho absoluto sempre, til (~) e
caminho relativo não expandem. Já existe um `.mcp.json.example` na raiz como
referência do formato.

Por fim, ativar o plugin do MCP dentro do projeto Godot:
1. Copie a pasta `addons/godot_mcp/` do repositório clonado pra dentro deste projeto.
2. Abra o projeto no Godot.
3. Project, Project Settings, Plugins, ative o "Godot MCP".

---

## 3. Verificação do MCP

1. Abra o Godot com este projeto carregado.
2. Abra o Claude Code na pasta do projeto. Se acabou de adicionar o servidor stdio,
   inicie uma sessão nova pra ele carregar as ferramentas.
3. Cheque o status com `/mcp` ou `claude mcp list`.
4. Teste de sanidade: peça "Liste todos os nós da cena atual com tipo e contagem de
   filhos". Se voltar a árvore limpa em segundos, está conectado.

Se travar ou voltar vazio: confirme que o Godot está aberto com o projeto, que o
plugin está ativo, e que o caminho no `.mcp.json` é absoluto e correto.

---

## 4. Regras de trabalho (importante, economiza tempo e evita retrabalho)

1. **Uma fatia por vez.** Ao terminar uma parte, rode o jogo pelo MCP e mostre o
   resultado por screenshot antes de seguir pra próxima. Não crie muitos arquivos
   de uma vez.
2. **Crie cenas e scripts pelo MCP**, não cole código gigante no chat.
3. **GDScript tipado** sempre que possível, comentado em português.
4. **Stats como Resource (.tres)**, pra balancear sem mexer em código.
5. **Estado global em autoloads**: GridManager, GameManager, AudioManager.
6. **Comunicação por signals**, não por referência forte entre nós.
7. **Atualize o GDD.md** quando uma decisão mudar. O GDD é o cérebro do projeto.
8. **Assets pesados** vão pro projeto e são referenciados por caminho, nunca anexados
   no chat.
9. **Nunca** coloque chaves de API no chat. Use `.env` ou variáveis de ambiente.

---

## 5. Tarefa atual: Fase 2, vertical slice

O objetivo é provar que o loop é divertido antes de qualquer arte fina. Construa,
nesta ordem, parando pra mostrar o resultado a cada bloco:

1. **Estrutura e arena.** Crie a estrutura de pastas do GDD (seção 14). Cena raiz
   Node3D. Camera3D ortográfica, top-down com inclinação de cerca de 60 graus pro
   look 2.5D. Luz direcional simples. Arena com grade lógica de 12x12 tiles.
   Crie o autoload `GridManager` com `grid_to_world`, `world_to_grid`, controle de
   ocupação de tiles e lista de armadilhas com dono. PARE e mostre rodando.

2. **Player e Healer.** CharacterBody3D com movimento livre por WASD e gamepad,
   placeholder de cápsula colorida. Healer (vida) começando em 100, fim de partida
   ao zerar. PARE e mostre.

3. **Armadilha Mina (a única do slice).** Botão de plantar faz snap no centro do
   tile mais próximo. Não planta em tile já ocupado. Arma após 0.5s, invisível pro
   inimigo. Explode quando o inimigo entra no tile, com dano e knockback.
   Inventário de 4 minas. Após explodir, a mina volta ao inventário em 6 segundos.
   PARE e mostre.

4. **Bot inimigo.** CharacterBody3D que persegue o player em linha simples, pode
   pisar nas minas. Sem IA de armadilha ainda. PARE e mostre.

5. **Regras de vitória e HUD.** Vitória por zerar o Healer do oponente em 90s. Se o
   tempo acabar, vence quem tomou menos dano. HUD: dois Healers, timer, contador de
   minas. PARE e mostre.

Critério de pronto da Fase 2: dá pra ganhar uma partida plantando minas contra o
bot, e é divertido. Só depois disso seguimos pra Fase 3 (sistema completo de
armadilhas), conforme o roadmap do GDD (seção 15).

---

## 6. Resumo da stack e do design (detalhe no GDD)

- Engine: Godot 4.x, GDScript tipado.
- Visual: 2.5D, modelos 3D em câmera top-down, neon urbano.
- Mecânica: 6 armadilhas (Detonador, Mina, Bomba, Gás, Cova, Painel de Força),
  Caution Mode pra detectar, desarme com código, retomada da própria armadilha.
- Combate: projétil com recarga, corpo a corpo com knockdown, super de Plasma (Unit).
- Vaults (P.O.D.S.): pontos que soltam itens na partida.
- Roster: 6 personagens originais (Brecht, Magnus, Vesna, Pip, Kestrel, Mara).
- Mundo: megacorp VECTOR, cyberpunk urbano.
- MVP: só local mais bot. Online fica pra fase 8.

Tudo detalhado no `GDD.md`. Consulte-o sempre.
