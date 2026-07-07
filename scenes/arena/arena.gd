extends Node3D
## Arena — cena de partida.
##
## A ESTRUTURA visual (câmera ortográfica top-down, luz, chão, ambiente e o player)
## está GRAVADA na cena arena.tscn — então aparece direto no editor, sem rodar.
## Aqui no script fica só o que é dinâmico: montar o mapa escolhido (grid, Vaults,
## field traps, estruturas 3D), o reset de round, a câmera-segue e a oclusão de pontes.
##
## A suíte de testes headless e as demos de captura moram em `scripts/dev_arena.gd`
## (extraídas daqui — arena.gd chegou a ter 1489 linhas com tudo misturado).

@onready var player: CharacterBody3D = $Player
@onready var bot: CharacterBody3D = $Bot

## Pontes com oclusão dinâmica (somem quando alguém passa embaixo — GDD 11).
var _pontes: Array = []
## Guardados pra resetar a cada round (GDD 12).
var _mapa: Resource = null
var _oponente: Node = null
## Câmera que segue o player em mapas grandes (estilo Trap Gunner).
var _seguir_camera: bool = false
var _cam_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_aplicar_textura_chao()
	_desenhar_grid()
	player.healer_zerou.connect(_ao_player_morrer)
	bot.healer_zerou.connect(_ao_bot_morrer)
	print("[Arena] pronta — grid %dx%d, tile %.1fu" % [GridManager.LARGURA, GridManager.ALTURA, GridManager.TAMANHO_TILE])
	var args := OS.get_cmdline_user_args()
	# Modos de desenvolvimento (--teste / --demo* / --capturar): o DevArena assume a cena.
	var dev := preload("res://scripts/dev_arena.gd").new()
	add_child(dev)
	if dev.executar(self, args):
		return
	dev.queue_free()
	# Greybox vertical JOGÁVEL: monta a arena com altura e inicia a partida (rodar em casa).
	if "--greybox" in args:
		_construir_greybox()
		player.gravidade_ativa = true
		bot.gravidade_ativa = true
		player.global_position = Vector3(-6.0, 1.0, 7.0)
		bot.global_position = Vector3(6.0, 1.0, -7.0)
		$HUD.configurar(player, bot)
		add_child(preload("res://scenes/ui/pausa.tscn").instantiate())
		GameManager.iniciar_partida([player, bot])
		return
	# Arena vertical COMPLETA jogável: escolhe o mapa vertical e segue o fluxo normal.
	if "--vertical" in args:
		GameManager.mapa = "res://resources/mapas/vertical.tres"
	# Mapa por dados (Fase 6): escolhe o mapa (GameManager), redimensiona o grid e monta tudo.
	var caminho_mapa := GameManager.mapa if GameManager.mapa != "" else "res://resources/mapas/padrao.tres"
	var mapa: Resource = load(caminho_mapa)
	GridManager.configurar_mapa(mapa)
	_desenhar_grid()
	if mapa.vertical:
		player.gravidade_ativa = true
		_montar_estruturas(mapa)   # chão, paredes, pontes, rampas (3D com colisão)
	player.global_position = GridManager.grid_to_world(mapa.spawn_jogador)
	player.global_position.y = 1.0
	# Oponente: o bot (VS COM) ou um 2º jogador local com gamepad 1 (VS MAN — GDD 12).
	var oponente: Node = bot
	if GameManager.modo == "vs_man":
		bot.queue_free()
		var p2 := preload("res://scenes/characters/player.tscn").instantiate()
		p2.id_jogador = 2
		p2.jogador_num = 2
		add_child(p2)
		p2.healer_zerou.connect(_ao_bot_morrer)
		oponente = p2
	oponente.global_position = GridManager.grid_to_world(mapa.spawn_bot)
	oponente.global_position.y = 1.0
	oponente.gravidade_ativa = mapa.vertical
	# Personagens escolhidos na tela de seleção (se houver).
	if GameManager.personagem_jogador != "":
		player.aplicar_personagem(load(GameManager.personagem_jogador))
	if GameManager.personagem_bot != "":
		oponente.aplicar_personagem(load(GameManager.personagem_bot))
	# Modo normal de jogo: liga a HUD e inicia a partida (rounds + regras de vitória).
	_mapa = mapa
	_oponente = oponente
	# Câmera segue o player em mapas grandes (Trap Gunner). Offset = pose inicial da câmera.
	if mapa.get("camera_segue"):
		var cam := get_node_or_null("Camera3D") as Camera3D
		if cam != null:
			_cam_offset = cam.position
			_seguir_camera = true
	$HUD.configurar(player, oponente)
	for c in mapa.vaults:
		_colocar_vault(c)                           # Vaults do mapa (GDD 8)
	_colocar_field_traps(mapa)                      # caixas, esteiras, lançadores, pontes
	add_child(preload("res://scenes/ui/pausa.tscn").instantiate())  # menu de pausa (ESC)
	GameManager.faltam_30s.connect(_ao_faltar_30s)  # Spark Bit aos 30s (GDD 7.3)
	GameManager.round_comecou.connect(_ao_round_comecou)  # reset a cada round (GDD 12)
	GameManager.iniciar_partida([player, oponente])


## Reset de round (GDD 12): limpa armadilhas/projeteis/itens/fx, restaura vida e
## reposiciona os combatentes nos spawns. Field traps e Vaults do mapa permanecem.
func _ao_round_comecou(_numero: int) -> void:
	GridManager.limpar_armadilhas()
	for grupo in ["armadilhas", "projeteis", "plasmas", "itens", "fx"]:
		for n in get_tree().get_nodes_in_group(grupo):
			n.queue_free()
	player.reiniciar()
	player.global_position = GridManager.grid_to_world(_mapa.spawn_jogador)
	player.global_position.y = 1.0
	if _oponente != null and is_instance_valid(_oponente):
		_oponente.reiniciar()
		_oponente.global_position = GridManager.grid_to_world(_mapa.spawn_bot)
		_oponente.global_position.y = 1.0


## Instancia os field traps do mapa (GDD 10) nos tiles indicados. Posição antes do
## add_child quando o _ready depende dela (esteira marca o tile).
func _colocar_field_traps(mapa: Resource) -> void:
	for c in mapa.obstaculos:
		_instanciar_em("res://scenes/field_traps/caixa.tscn", c, {"tipo": "obstaculo"})
	for c in mapa.bombas_caixa:
		_instanciar_em("res://scenes/field_traps/caixa.tscn", c, {"tipo": "bomba"})
	for c in mapa.esteiras:
		_instanciar_em("res://scenes/field_traps/esteira.tscn", c, {})
	for c in mapa.pontes:
		_instanciar_em("res://scenes/field_traps/ponte.tscn", c, {})
	for c in mapa.lancadores:
		# Laser mira pro centro da arena (na origem), pra varrer pra dentro, não pra fora.
		var wp := GridManager.grid_to_world(c)
		var dir := Vector3(-wp.x, 0.0, -wp.z)
		if dir.length() < 0.5:
			dir = Vector3(0.0, 0.0, 1.0)
		_instanciar_em("res://scenes/field_traps/lancador.tscn", c, {"tipo": "laser", "direcao": dir})
	for c in mapa.cannons:
		_instanciar_em("res://scenes/field_traps/lancador.tscn", c, {"tipo": "foguete"})


## Carrega uma cena, define propriedades e posiciona no centro do tile (y do chão).
func _instanciar_em(caminho: String, coord: Vector2i, props: Dictionary) -> Node:
	var n: Node = load(caminho).instantiate()
	for k in props:
		n.set(k, props[k])
	n.position = GridManager.grid_to_world(coord)  # antes do add_child (esteira lê o tile)
	add_child(n)
	return n


## Instancia uma Vault no centro de um tile (cospe itens durante a partida).
## Define a posição ANTES do add_child pro _ready da Vault ler o tile certo.
func _colocar_vault(coord: Vector2i) -> Node:
	var v := preload("res://scenes/items/vault.tscn").instantiate()
	v.position = GridManager.grid_to_world(coord)  # arena na origem: local == mundo
	add_child(v)
	return v


## Spark Bit no centro da arena quando faltam 30s (perigo que força ação).
func _ao_faltar_30s() -> void:
	var s := preload("res://scenes/items/spark_bit.tscn").instantiate()
	add_child(s)
	s.global_position = Vector3(0.0, 1.0, 0.0)


## Oclusão das pontes: cada ponte fica transparente quando há um combatente embaixo dela
## (mesma vertical, y menor), e volta a sólida quando ninguém está. Fade suave.
func _process(delta: float) -> void:
	_seguir_player(delta)
	if _pontes.is_empty():
		return
	for p in _pontes:
		var alguem := false
		for c in get_tree().get_nodes_in_group("combatentes"):
			if not is_instance_valid(c):
				continue
			var d: Vector3 = c.global_position - p["centro"]
			if absf(d.x) <= p["tamanho"].x * 0.5 and absf(d.z) <= p["tamanho"].z * 0.5 \
					and c.global_position.y < p["centro"].y - 0.2:
				alguem = true
				break
		var mat: StandardMaterial3D = p["mat"]
		var cor: Color = mat.albedo_color
		cor.a = lerpf(cor.a, 0.3 if alguem else 1.0, minf(1.0, delta * 8.0))
		mat.albedo_color = cor


## Câmera segue o player em XZ (mantendo o ângulo/altura 2.5D), com suavização.
func _seguir_player(delta: float) -> void:
	if not _seguir_camera or player == null or not is_instance_valid(player):
		return
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var alvo := Vector3(player.global_position.x, 0.0, player.global_position.z) + _cam_offset
	cam.global_position = cam.global_position.lerp(alvo, 1.0 - exp(-delta * 6.0))


## Aplica `assets/sprites/chao.png` como textura do chão (tileada), se o arquivo existir.
## Plug-and-play: é só largar o PNG na pasta (igual os ícones das armadilhas).
func _aplicar_textura_chao() -> void:
	var caminho := "res://assets/sprites/chao.png"
	if not ResourceLoader.exists(caminho):
		return
	# Carrega a textura JÁ IMPORTADA (export-safe). Image.load() em runtime dá warning
	# e quebra no export — load() pega o .ctex que o editor gera a partir do PNG.
	var tex := load(caminho) as Texture2D
	if tex == null:
		return
	var chao := get_node_or_null("Chao") as MeshInstance3D
	if chao == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	# Imagem de arena INTEIRA (com logo/marcas) → cobre o chão 1:1, sem repetir.
	# (Se um dia for um tile sem-emenda, é só voltar pra uv1_scale 6×6.)
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.roughness = 0.85
	chao.material_override = mat


func _ao_player_morrer() -> void:
	print("[Arena] Healer do jogador zerou — fim de partida (placeholder).")


func _ao_bot_morrer() -> void:
	print("[Arena] Healer do bot zerou — jogador venceu (placeholder).")


## Desenha as linhas do grid como ImmediateMesh, em neon ciano discreto. Roda ao jogar.
func _desenhar_grid() -> void:
	var antigo := get_node_or_null("LinhasGrid")  # redesenho seguro (mapa pode mudar)
	if antigo != null:
		antigo.queue_free()  # queue_free: seguro mesmo durante o _ready (árvore ocupada)
	var linhas := MeshInstance3D.new()
	linhas.name = "LinhasGrid"
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.85, 1.0, 0.45)

	var lg := GridManager.LARGURA
	var al := GridManager.ALTURA
	var ts := GridManager.TAMANHO_TILE
	var meio_x := float(lg) * ts * 0.5
	var meio_z := float(al) * ts * 0.5
	var y := 0.02  # levemente acima do chão pra não dar z-fighting

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	# Linhas paralelas ao eixo Z (divisórias entre colunas)
	for i in range(lg + 1):
		var x := float(i) * ts - meio_x
		im.surface_add_vertex(Vector3(x, y, -meio_z))
		im.surface_add_vertex(Vector3(x, y, meio_z))
	# Linhas paralelas ao eixo X (divisórias entre linhas)
	for j in range(al + 1):
		var z := float(j) * ts - meio_z
		im.surface_add_vertex(Vector3(-meio_x, y, z))
		im.surface_add_vertex(Vector3(meio_x, y, z))
	im.surface_end()

	linhas.mesh = im
	add_child(linhas)


# ─────────────────── Construção de estruturas 3D (mapas verticais) ───────────────────

## Cria um bloco sólido (StaticBody3D + colisão) pro greybox. Alfa<1 = semitransparente.
func _caixa_solida(pos: Vector3, tamanho: Vector3, cor: Color, rot_x: float = 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tamanho
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	if cor.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tamanho
	cs.shape = box
	sb.add_child(cs)
	sb.add_to_group("geometria")   # facilita limpar nos testes
	add_child(sb)
	sb.position = pos
	sb.rotation.x = rot_x
	return sb


## Monta a geometria vertical do greybox: chão com colisão, ponte elevada (passa-se por
## baixo), rampa de acesso e paredes laterais (corredor).
func _construir_greybox() -> void:
	_caixa_solida(Vector3(0.0, -0.1, 0.0), Vector3(24.0, 0.2, 24.0), Color(0.12, 0.13, 0.18))  # chão
	_construir_ponte(Vector3(0.0, 2.6, 0.0), Vector3(12.0, 0.3, 3.0))                            # ponte (oclui)
	_caixa_solida(Vector3(0.0, 1.3, -5.5), Vector3(3.0, 0.3, 6.0), Color(0.45, 0.5, 0.65), deg_to_rad(-25.0))  # rampa
	_caixa_solida(Vector3(-9.0, 0.6, 0.0), Vector3(0.4, 1.2, 18.0), Color(0.2, 0.22, 0.3))  # parede
	_caixa_solida(Vector3(9.0, 0.6, 0.0), Vector3(0.4, 1.2, 18.0), Color(0.2, 0.22, 0.3))   # parede


## Cria uma rampa inclinada ligando um ponto baixo a um alto (ao longo de X ou Z).
func _rampa(baixo: Vector3, alto: Vector3, largura: float) -> StaticBody3D:
	var meio := (baixo + alto) * 0.5
	var delta := alto - baixo
	var sb: StaticBody3D
	if absf(delta.z) >= absf(delta.x):           # rampa ao longo de Z (norte/sul)
		var comp := absf(delta.z) + 1.0
		sb = _caixa_solida(meio, Vector3(largura, 0.3, comp), Color(0.45, 0.5, 0.65))
		var ang := atan2(delta.y, absf(delta.z))
		sb.rotation.x = ang if delta.z < 0.0 else -ang
	else:                                        # rampa ao longo de X (leste/oeste)
		var comp := absf(delta.x) + 1.0
		sb = _caixa_solida(meio, Vector3(comp, 0.3, largura), Color(0.45, 0.5, 0.65))
		var ang := atan2(delta.y, absf(delta.x))
		sb.rotation.z = -ang if delta.x < 0.0 else ang
	return sb


## Monta as estruturas 3D de um mapa vertical a partir dos DADOS (StatsMapa.estruturas).
func _montar_estruturas(mapa: Resource) -> void:
	for e in mapa.estruturas:
		match String(e.get("tipo", "")):
			"chao":
				var sb_chao := _caixa_solida(e["pos"], e["tam"], Color(0.12, 0.13, 0.18))
				_texturizar_chao(sb_chao, e["tam"])
			"parede":
				_caixa_solida(e["pos"], e["tam"], Color(0.2, 0.22, 0.3))
			"pilar":
				_caixa_solida(e["pos"], e["tam"], Color(0.25, 0.26, 0.34))
			"ponte":
				_construir_ponte(e["pos"], e["tam"])
			"rampa":
				_rampa(e["de"], e["ate"], float(e.get("larg", 3.0)))


## Carrega uma textura PNG crua (sem precisar importar pelo editor), com mipmaps.
func _carregar_tex_arena(caminho: String) -> Texture2D:
	if not FileAccess.file_exists(caminho):
		return null
	var img := Image.new()
	if img.load(caminho) != OK:
		return null
	img.generate_mipmaps()                 # evita serrilhado no chão ladrilhado ao longe
	return ImageTexture.create_from_image(img)


## Aplica a textura de metal tileável (ambientCG) no chão estrutural, repetida pelo tamanho.
## Sem os PNGs, mantém a cor cinza placeholder.
func _texturizar_chao(sb: StaticBody3D, tam: Vector3) -> void:
	var cor := _carregar_tex_arena("res://assets/sprites/chao_tile.png")
	if cor == null:
		return
	var mi := sb.get_child(0) as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = cor
	mat.albedo_color = Color(1.35, 1.35, 1.45)               # clareia um tom (leve azulado)
	mat.uv1_scale = Vector3(tam.x / 8.0, tam.z / 8.0, 1.0)   # placas maiores (menos repetitivo)
	mat.metallic = 0.25                                       # metal fosco (sem virar espelho escuro)
	var rough := _carregar_tex_arena("res://assets/sprites/chao_tile_rough.png")
	if rough != null:
		mat.roughness_texture = rough
	else:
		mat.roughness = 0.7
	mi.material_override = mat


## Builder da arena vertical (usado pelo --demo-vertical): carrega o mapa .tres por dados.
func _montar_arena_vertical() -> void:
	_montar_estruturas(load("res://resources/mapas/vertical.tres"))


## Cria uma ponte sólida e a registra pra oclusão dinâmica (some quem passa por baixo vê).
func _construir_ponte(pos: Vector3, tamanho: Vector3) -> StaticBody3D:
	var sb := _caixa_solida(pos, tamanho, Color(0.5, 0.55, 0.7, 1.0))
	var mi := sb.get_child(0) as MeshInstance3D
	var mat := mi.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # pra poder esmaecer
	_pontes.append({"no": sb, "mat": mat, "centro": pos, "tamanho": tamanho})
	return sb
