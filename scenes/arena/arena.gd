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
## Split-screen do VS MAN: [{ "cam": Camera3D, "alvo": Node3D }, ...]. Vazio = tela única.
var _cams_split: Array = []
## Limites (±x, ±z) do foco da câmera, pra não mostrar o vazio além das paredes.
var _cam_limite: Vector2 = Vector2(1.0e9, 1.0e9)

## Texturas CC0 (ambientCG) usadas no visual do mapa — conjunto PBR completo.
const TEX_CHAO := "res://assets/sprites/texturas/MetalPlates006_1K-JPG_Color.jpg"
const TEX_CHAO_NORMAL := "res://assets/sprites/texturas/MetalPlates006_1K-JPG_NormalGL.jpg"
const TEX_CHAO_ROUGH := "res://assets/sprites/texturas/MetalPlates006_1K-JPG_Roughness.jpg"


## Aplica o conjunto PBR de placas de metal (albedo+normal+roughness) num material.
## O relevo real das placas é o que separa "greybox" de "piso industrial".
static func _aplicar_pbr_metal(mat: StandardMaterial3D) -> void:
	if ResourceLoader.exists(TEX_CHAO):
		mat.albedo_texture = load(TEX_CHAO) as Texture2D
	if ResourceLoader.exists(TEX_CHAO_NORMAL):
		mat.normal_enabled = true
		mat.normal_texture = load(TEX_CHAO_NORMAL) as Texture2D
		mat.normal_scale = 0.8
	if ResourceLoader.exists(TEX_CHAO_ROUGH):
		mat.roughness_texture = load(TEX_CHAO_ROUGH) as Texture2D

## Os 3 ângulos de câmera do Trap Gunner original (tecla V alterna; persiste em
## settings): Normal (inclinada), Quarter (mais alta) e Top (quase reta de cima).
## Formato: [fov, distância, inclinação em graus].
const CAM_PRESETS := {
	"normal": [48.0, 21.0, 54.0],
	"quarter": [45.0, 24.0, 66.0],
	"top": [40.0, 26.0, 84.0],
}
const CAM_ORDEM: Array = ["normal", "quarter", "top"]
var _cam_preset: String = "normal"


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
	_montar_visual_mapa(mapa)   # chão xadrez + paredes + câmera (estilo Trap Gunner)
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
	$HUD.configurar(player, oponente)
	# VS MAN: tela DIVIDIDA (marca registrada do Trap Gunner) — cada jogador tem a sua
	# câmera seguindo o próprio personagem. VS COM continua em tela única.
	if GameManager.modo == "vs_man":
		_montar_split_screen(player, oponente)
	for c in mapa.vaults:
		_colocar_vault(c)                           # Vaults do mapa (GDD 8)
	_colocar_field_traps(mapa)                      # caixas, esteiras, lançadores, pontes
	add_child(preload("res://scenes/ui/pausa.tscn").instantiate())  # menu de pausa (ESC)
	GameManager.faltam_30s.connect(_ao_faltar_30s)  # Spark Bit aos 30s (GDD 7.3)
	GameManager.round_comecou.connect(_ao_round_comecou)  # reset a cada round (GDD 12)
	GameManager.round_acabou.connect(_ao_round_acabou)    # vencedor comemora (animação)
	AudioManager.tocar_musica()                           # trilha de fundo (loop)
	AudioManager.tocar_ambiencia()                        # hum do complexo + ecos distantes
	GameManager.iniciar_partida([player, oponente])


## Fim de round: o vencedor comemora durante a pausa "ROUND N" (animação Cheer).
func _ao_round_acabou(vencedor_id: int, _motivo: String, _v1: int, _v2: int) -> void:
	for c in [player, _oponente]:
		if c != null and is_instance_valid(c) and int(c.get("id_jogador")) == vencedor_id \
				and c.has_method("comemorar"):
			c.comemorar(GameManager.PAUSA_ENTRE_ROUNDS + 1.0)


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


## Câmera segue o alvo em XZ (mantendo o ângulo), com suavização e clamp nas bordas
## do mapa. Tela única: a câmera principal segue o player. Split (VS MAN): cada
## câmera segue o SEU jogador.
func _seguir_player(delta: float) -> void:
	for entrada in _cams_split:
		var alvo_no: Node3D = entrada["alvo"]
		if is_instance_valid(alvo_no):
			_seguir_alvo(entrada["cam"], alvo_no.global_position, delta)
	if not _seguir_camera or player == null or not is_instance_valid(player):
		return
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	_seguir_alvo(cam, player.global_position, delta)


func _seguir_alvo(cam: Camera3D, pos: Vector3, delta: float) -> void:
	var foco := Vector3(pos.x, 0.0, pos.z)
	foco.x = clampf(foco.x, -_cam_limite.x, _cam_limite.x)
	foco.z = clampf(foco.z, -_cam_limite.y, _cam_limite.y)
	var alvo := foco + _cam_offset
	cam.global_position = cam.global_position.lerp(alvo, 1.0 - exp(-delta * 6.0))


## Split-screen do VS MAN (fidelidade ao original): dois SubViewports lado a lado
## COMPARTILHANDO o mundo da arena (own_world_3d = false), cada um com a própria
## câmera (mesmo preset da câmera única + screenshake) seguindo o seu jogador.
## A HUD (CanvasLayer, layer 1) fica por cima das duas telas.
func _montar_split_screen(p1: Node3D, p2: Node3D) -> void:
	var cam_principal := get_node_or_null("Camera3D") as Camera3D
	if cam_principal != null:
		cam_principal.current = false
	_seguir_camera = false            # a câmera única não segue; as do split seguem
	var ui := CanvasLayer.new()
	ui.name = "SplitScreen"
	ui.layer = 0                      # abaixo da HUD (layer 1)
	add_child(ui)
	var caixa := HBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.add_theme_constant_override("separation", 4)
	ui.add_child(caixa)
	var p: Array = CAM_PRESETS.get(_cam_preset, CAM_PRESETS["normal"])
	var tilt := deg_to_rad(float(p[2]))
	_cam_offset = Vector3(0.0, sin(tilt), cos(tilt)) * float(p[1])
	_cams_split.clear()
	for alvo in [p1, p2]:
		var cont := SubViewportContainer.new()
		cont.stretch = true
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caixa.add_child(cont)
		var vp := SubViewport.new()
		vp.own_world_3d = false        # MESMO mundo da arena nas duas telas
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		cont.add_child(vp)
		var cam := Camera3D.new()
		cam.set_script(preload("res://scenes/arena/camera_tremor.gd"))  # shake nas duas
		vp.add_child(cam)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = float(p[0])
		cam.rotation_degrees = Vector3(-float(p[2]), 0.0, 0.0)
		cam.position = (alvo as Node3D).global_position + _cam_offset
		cam.current = true
		# Cada tela esconde as armadilhas do ADVERSÁRIO (mind games do split).
		var id := int((alvo as Node).get("id_jogador"))
		cam.cull_mask = 0xFFFFF & ~((1 << 11) if id == 1 else (1 << 10))
		_cams_split.append({"cam": cam, "alvo": alvo})


# ──────────────── Visual do mapa (estilo Trap Gunner — ver PLANO_REMAKE_VISUAL) ────────────────

## Monta o visual de um mapa plano: chão xadrez cobrindo EXATAMENTE o grid, paredes com
## colisão no perímetro e a câmera perspectiva inclinada. Mapas verticais mantêm as
## estruturas próprias (chão texturizado) e só ganham a câmera.
func _montar_visual_mapa(mapa: Resource) -> void:
	_mapa = mapa   # cedo: as paredes usam a cor do tema no friso neon
	_configurar_camera()
	var chao_antigo := get_node_or_null("Chao")
	if chao_antigo != null:
		chao_antigo.visible = false        # o plano fixo 24×24 não serve pra mapa por dados
	var linhas := get_node_or_null("LinhasGrid")
	if linhas != null:
		linhas.queue_free()                # o xadrez JÁ marca o grid (sem linhas neon)
	if mapa.vertical:
		_desenhar_grid()                   # mapas verticais: estruturas próprias + linhas
		return
	_montar_chao_tiles(mapa)
	_montar_chao_identidade(mapa)
	_montar_paredes()
	_montar_avental()
	_montar_decoracao(mapa)


## IDENTIDADE do piso (Art Bible §5 — "usado por décadas, sinalizado por burocratas"):
## faixa amarela/preta no perímetro, estêncil do setor, manchas de óleo/queimadura e
## grelhas de ventilação com vapor. Tudo decal fino ACIMA das placas, sem colisão.
func _montar_chao_identidade(mapa: Resource) -> void:
	var antigo := get_node_or_null("ChaoIdentidade")
	if antigo != null:
		antigo.queue_free()
	var raiz := Node3D.new()
	raiz.name = "ChaoIdentidade"
	add_child(raiz)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(mapa.nome)) + 7
	var ts := GridManager.TAMANHO_TILE
	var w := float(GridManager.LARGURA) * ts * 0.5
	var h := float(GridManager.ALTURA) * ts * 0.5
	# ── Faixa de segurança amarelo/preto contornando o campo (rente às paredes).
	var seg := BoxMesh.new()
	seg.size = Vector3(1.0, 0.02, 0.34)
	var mat_amarelo := StandardMaterial3D.new()
	mat_amarelo.albedo_color = Color(0.85, 0.65, 0.1)
	mat_amarelo.roughness = 0.9
	var mat_preto := StandardMaterial3D.new()
	mat_preto.albedo_color = Color(0.06, 0.06, 0.07)
	mat_preto.roughness = 0.9
	var tf_am: Array[Transform3D] = []
	var tf_pr: Array[Transform3D] = []
	var passo := 1.0
	var nx := int(w * 2.0 / passo)
	for i in nx:
		var x := -w + 0.5 + float(i) * passo
		for zz in [-h + 0.22, h - 0.22]:
			var t := Transform3D(Basis.IDENTITY, Vector3(x, 0.015, zz))
			if i % 2 == 0:
				tf_am.append(t)
			else:
				tf_pr.append(t)
	var nz := int(h * 2.0 / passo) - 1
	for i in nz:
		var z := -h + 1.0 + float(i) * passo
		for xx in [-w + 0.22, w - 0.22]:
			var t2 := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(xx, 0.015, z))
			if i % 2 == 0:
				tf_am.append(t2)
			else:
				tf_pr.append(t2)
	for par in [[tf_am, mat_amarelo], [tf_pr, mat_preto]]:
		var lista: Array = par[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = seg
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = par[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mmi)
	# ── Estêncil do setor pintado no piso (desbotado — burocracia VECTOR).
	var estencil := Label3D.new()
	estencil.text = String(mapa.nome).to_upper()
	estencil.font_size = 200
	estencil.pixel_size = 0.007
	estencil.modulate = Color(0.9, 0.92, 1.0, 0.09)
	estencil.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	raiz.add_child(estencil)
	estencil.position = Vector3(-w * 0.35, 0.03, h * 0.35)
	# ── Manchas de óleo e queimaduras antigas (o setor tem passado).
	for i in 9:
		var mancha := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := rng.randf_range(0.5, 1.3)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.012
		cm.radial_segments = 10
		mancha.mesh = cm
		var matm := StandardMaterial3D.new()
		matm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		matm.albedo_color = Color(0.01, 0.01, 0.015, rng.randf_range(0.25, 0.5))
		matm.roughness = 0.25 if rng.randf() < 0.5 else 0.9   # óleo brilha, queimadura não
		mancha.material_override = matm
		mancha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mancha)
		mancha.position = Vector3(rng.randf_range(-w + 2.0, w - 2.0), 0.012, rng.randf_range(-h + 2.0, h - 2.0))
	# ── Grelhas de ventilação em tiles fixos por seed (2 soltam vapor).
	for i in 5:
		var gx := rng.randi_range(1, GridManager.LARGURA - 2)
		var gy := rng.randi_range(1, GridManager.ALTURA - 2)
		var p := GridManager.grid_to_world(Vector2i(gx, gy))
		var grelha := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(ts * 0.7, 0.025, ts * 0.7)
		grelha.mesh = gm
		var matg := StandardMaterial3D.new()
		matg.albedo_color = Color(0.11, 0.12, 0.15)
		matg.metallic = 0.7
		matg.roughness = 0.4
		grelha.material_override = matg
		grelha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(grelha)
		grelha.position = Vector3(p.x, 0.015, p.z)
		if i < 2:
			var vapor := CPUParticles3D.new()
			vapor.amount = 10
			vapor.lifetime = 2.4
			vapor.preprocess = 2.4
			vapor.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			vapor.emission_box_extents = Vector3(ts * 0.3, 0.05, ts * 0.3)
			vapor.direction = Vector3.UP
			vapor.spread = 10.0
			vapor.initial_velocity_min = 0.3
			vapor.initial_velocity_max = 0.7
			vapor.gravity = Vector3(0.0, 0.15, 0.0)
			vapor.scale_amount_min = 0.6
			vapor.scale_amount_max = 1.2
			var vm := SphereMesh.new()
			vm.radius = 0.1
			vm.height = 0.2
			vapor.mesh = vm
			var vmat := StandardMaterial3D.new()
			vmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			vmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			vmat.albedo_color = Color(0.75, 0.8, 0.9, 0.06)
			vapor.mesh.surface_set_material(0, vmat)
			raiz.add_child(vapor)
			vapor.position = Vector3(p.x, 0.1, p.z)
			vapor.emitting = true


## Piso escuro GIGANTE por baixo de tudo: o que aparece além das paredes deixa de ser
## vazio preto e vira "fora da arena" intencional.
func _montar_avental() -> void:
	var antigo := get_node_or_null("Avental")
	if antigo != null:
		antigo.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "Avental"
	var pm := PlaneMesh.new()
	var ts := GridManager.TAMANHO_TILE
	pm.size = Vector2(GridManager.LARGURA * ts * 3.0, GridManager.ALTURA * ts * 3.0)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.10, 0.14)
	mat.roughness = 1.0
	# Mesmo metal do chão, bem escurecido e repetido: "fora da arena" vira piso
	# industrial em sombra (o fog dilui ao longe), não um vazio chapado.
	if ResourceLoader.exists(TEX_CHAO):
		_aplicar_pbr_metal(mat)
		mat.albedo_color = Color(0.16, 0.17, 0.22)
		mat.uv1_scale = Vector3(24.0, 24.0, 1.0)
	mi.material_override = mat
	add_child(mi)
	mi.position.y = -0.3


## Chão em PLACAS por tile (duas cores alternadas — leitura de grid imediata, cara de
## Trap Gunner). MultiMesh: 2 draw calls pro chão inteiro, qualquer tamanho de mapa.
func _montar_chao_tiles(mapa: Resource) -> void:
	var antigo := get_node_or_null("ChaoTiles")
	if antigo != null:
		antigo.queue_free()
	var raiz := Node3D.new()
	raiz.name = "ChaoTiles"
	add_child(raiz)
	var ts := GridManager.TAMANHO_TILE
	var box := BoxMesh.new()
	box.size = Vector3(ts * 0.97, 0.14, ts * 0.97)   # fresta escura entre placas = grid
	# Tema do mapa: a cor A manda; a "B" é a MESMA placa só 12% mais escura (variação
	# sutil de lote de fabricação — o grid continua legível pela FRESTA, não por
	# xadrez de alto contraste, que lia como arcade/protótipo).
	var cor_a: Color = mapa.get("cor_tile_a") if mapa.get("cor_tile_a") != null else Color(0.34, 0.36, 0.42)
	var cor_b := Color(cor_a.r * 0.88, cor_a.g * 0.88, cor_a.b * 0.88)
	var cores := [cor_a, cor_b]
	# Junta as transforms por paridade (xadrez) e cria um MultiMesh por cor.
	var por_cor: Array = [[], []]
	for x in range(GridManager.LARGURA):
		for y in range(GridManager.ALTURA):
			var p := GridManager.grid_to_world(Vector2i(x, y))
			var t := Transform3D(Basis.IDENTITY, Vector3(p.x, -0.07, p.z))  # topo em y=0
			por_cor[(x + y) % 2].append(t)
	# Textura de placas de metal (ambientCG, CC0) tingida pelas 2 cores do tema.
	# O BoxMesh mapeia a textura 1:1 por face -> UMA placa por tile, sem emenda.
	var tem_tex := ResourceLoader.exists(TEX_CHAO)
	for ci in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		mm.instance_count = por_cor[ci].size()
		for i in por_cor[ci].size():
			mm.set_instance_transform(i, por_cor[ci][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		if tem_tex:
			_aplicar_pbr_metal(mat)   # albedo + normal + roughness (relevo real)
			var c: Color = cores[ci]
			mat.albedo_color = Color(minf(c.r * 2.0, 1.0), minf(c.g * 2.0, 1.0), minf(c.b * 2.0, 1.0))
		else:
			mat.albedo_color = cores[ci]
			mat.roughness = 0.85
		mat.metallic = 0.15
		mmi.material_override = mat
		raiz.add_child(mmi)


## Paredes de VERDADE no perímetro (acabamento Steam): base alta texturizada com
## colisão, friso NEON no topo na cor do tema do mapa e pilares nos cantos. Seguram
## os personagens dentro e fecham a leitura da arena como um "ringue".
func _montar_paredes() -> void:
	var ts := GridManager.TAMANHO_TILE
	var w := float(GridManager.LARGURA) * ts
	var h := float(GridManager.ALTURA) * ts
	var alt := 1.7
	var esp := 0.8
	var cor := Color(0.2, 0.21, 0.27)
	var lados := [
		_caixa_solida(Vector3(0.0, alt * 0.5, -h * 0.5 - esp * 0.5), Vector3(w + esp * 2.0, alt, esp), cor),
		_caixa_solida(Vector3(0.0, alt * 0.5, h * 0.5 + esp * 0.5), Vector3(w + esp * 2.0, alt, esp), cor),
		_caixa_solida(Vector3(-w * 0.5 - esp * 0.5, alt * 0.5, 0.0), Vector3(esp, alt, h + esp * 2.0), cor),
		_caixa_solida(Vector3(w * 0.5 + esp * 0.5, alt * 0.5, 0.0), Vector3(esp, alt, h + esp * 2.0), cor),
	]
	# Textura de metal PBR (triplanar: não estica no comprimento).
	if ResourceLoader.exists(TEX_CHAO):
		for sb in lados:
			var mi := (sb as Node).get_child(0) as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			_aplicar_pbr_metal(mat)
			mat.albedo_color = Color(0.55, 0.58, 0.68)
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	# Friso neon no topo de cada lado, na cor clara do tema (o glow faz ele "acender").
	var cor_neon: Color = _mapa.cor_tile_a if _mapa != null else Color(0.3, 0.6, 1.0)
	cor_neon = Color(minf(cor_neon.r * 2.4, 1.0), minf(cor_neon.g * 2.4, 1.0), minf(cor_neon.b * 2.4, 1.0))
	var mat_neon := StandardMaterial3D.new()
	mat_neon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_neon.albedo_color = cor_neon
	mat_neon.emission_enabled = true
	mat_neon.emission = cor_neon
	mat_neon.emission_energy_multiplier = 1.6
	var frisos := [
		[Vector3(0.0, alt + 0.04, -h * 0.5 - esp * 0.5), Vector3(w + esp * 2.0, 0.08, 0.2)],
		[Vector3(0.0, alt + 0.04, h * 0.5 + esp * 0.5), Vector3(w + esp * 2.0, 0.08, 0.2)],
		[Vector3(-w * 0.5 - esp * 0.5, alt + 0.04, 0.0), Vector3(0.2, 0.08, h + esp * 2.0)],
		[Vector3(w * 0.5 + esp * 0.5, alt + 0.04, 0.0), Vector3(0.2, 0.08, h + esp * 2.0)],
	]
	for f in frisos:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = f[1]
		mi.mesh = bm
		mi.material_override = mat_neon
		add_child(mi)
		mi.add_to_group("geometria")
		mi.position = f[0]
	# Pilares nos 4 cantos (fecham a moldura).
	for canto in [Vector3(-w * 0.5 - esp * 0.5, 0.0, -h * 0.5 - esp * 0.5),
			Vector3(w * 0.5 + esp * 0.5, 0.0, -h * 0.5 - esp * 0.5),
			Vector3(-w * 0.5 - esp * 0.5, 0.0, h * 0.5 + esp * 0.5),
			Vector3(w * 0.5 + esp * 0.5, 0.0, h * 0.5 + esp * 0.5)]:
		_caixa_solida(canto + Vector3(0.0, 1.15, 0.0), Vector3(1.2, 2.3, 1.2), Color(0.26, 0.27, 0.34))


## Alterna Normal -> Quarter -> Top com a tecla V (os 3 modos do original) e salva.
func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo \
			and evento.physical_keycode == KEY_V:
		var i := CAM_ORDEM.find(_cam_preset)
		_cam_preset = CAM_ORDEM[(i + 1) % CAM_ORDEM.size()]
		Persistencia.set_config("video", "camera", _cam_preset)
		Persistencia.salvar()
		_configurar_camera()


## Câmera Trap Gunner: perspectiva inclinada, seguindo o player com clamp. O preset
## (Normal/Quarter/Top) vem dos settings.
func _configurar_camera() -> void:
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	_cam_preset = String(Persistencia.get_config("video", "camera", _cam_preset))
	if not CAM_PRESETS.has(_cam_preset):
		_cam_preset = "normal"
	var p: Array = CAM_PRESETS[_cam_preset]
	var fov := float(p[0])
	var dist := float(p[1])
	var tilt_graus := float(p[2])
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = fov
	var tilt := deg_to_rad(tilt_graus)
	_cam_offset = Vector3(0.0, sin(tilt), cos(tilt)) * dist
	cam.rotation_degrees = Vector3(-tilt_graus, 0.0, 0.0)
	# A câmera do P1 NÃO renderiza a camada das armadilhas do oponente (invisíveis
	# de verdade — GDD seção 6; o Caution Mode é quem revela).
	cam.cull_mask = 0xFFFFF & ~(1 << 11)
	# Clamp do foco: quanto o mapa é maior que o enquadramento, deixa a câmera passear.
	var ts := GridManager.TAMANHO_TILE
	var w := float(GridManager.LARGURA) * ts
	var h := float(GridManager.ALTURA) * ts
	_cam_limite = Vector2(maxf(0.0, w * 0.5 - 10.0), maxf(0.0, h * 0.5 - 8.0))
	var foco := Vector3.ZERO
	if player != null and is_instance_valid(player):
		foco = Vector3(player.global_position.x, 0.0, player.global_position.z)
	foco.x = clampf(foco.x, -_cam_limite.x, _cam_limite.x)
	foco.z = clampf(foco.z, -_cam_limite.y, _cam_limite.y)
	cam.position = foco + _cam_offset
	_seguir_camera = true


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


# ───────────────── O GALPÃO (Art Bible §4: moldura + horizonte, fim do vazio) ─────────────────

## Constrói o COMPLEXO ao redor do campo: fachadas com janelas acesas, vigas no alto,
## pilares, passarela de manutenção, dutos, geradores, containers, holofotes apontados
## pro ringue, luzes de emergência piscando, poeira no ar. A arena vira uma SALA
## dentro de um prédio vivo. Determinístico por mapa (seed = hash do nome).
func _montar_decoracao(mapa: Resource) -> void:
	var antigo := get_node_or_null("Decoracao")
	if antigo != null:
		antigo.queue_free()
	var raiz := Node3D.new()
	raiz.name = "Decoracao"
	add_child(raiz)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(mapa.nome))
	var ts := GridManager.TAMANHO_TILE
	var w := float(GridManager.LARGURA) * ts * 0.5
	var h := float(GridManager.ALTURA) * ts * 0.5
	var cor_tema: Color = mapa.cor_tile_a
	# Materiais compartilhados da moldura (meia-luz) e horizonte (escuro).
	var mat_escuro := StandardMaterial3D.new()
	mat_escuro.albedo_color = Color(0.12, 0.13, 0.16)
	mat_escuro.metallic = 0.6
	mat_escuro.roughness = 0.5
	var mat_fachada := StandardMaterial3D.new()
	_aplicar_pbr_metal(mat_fachada)
	mat_fachada.albedo_color = Color(0.22, 0.24, 0.3)
	mat_fachada.uv1_triplanar = true
	mat_fachada.uv1_scale = Vector3(0.25, 0.25, 0.25)
	var mat_tema := StandardMaterial3D.new()
	mat_tema.albedo_color = Color(cor_tema.r * 0.55, cor_tema.g * 0.55, cor_tema.b * 0.55)
	mat_tema.metallic = 0.4
	mat_tema.roughness = 0.6
	var cor_luz := Color(minf(cor_tema.r * 2.2, 1.0), minf(cor_tema.g * 2.2, 1.0), minf(cor_tema.b * 2.2, 1.0))
	var mat_luz := StandardMaterial3D.new()
	mat_luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_luz.albedo_color = cor_luz
	mat_luz.emission_enabled = true
	mat_luz.emission = cor_luz
	mat_luz.emission_energy_multiplier = 1.4
	_galpao_fachadas(raiz, rng, w, h, mat_fachada)
	_galpao_vigas_e_holofotes(raiz, w, h, mat_escuro)
	_galpao_passarela(raiz, w, h, mat_escuro)
	_galpao_maquinas(raiz, rng, w, h, mat_escuro, mat_tema, mat_luz)
	_galpao_emergencia_e_ar(raiz, w, h)


## HORIZONTE: 4 fachadas internas do prédio com fileiras de JANELAS (parte acesa —
## a produção continua nos outros setores) + pilares estruturais.
func _galpao_fachadas(raiz: Node3D, rng: RandomNumberGenerator, w: float, h: float, mat_fachada: Material) -> void:
	var mat_janela_acesa := StandardMaterial3D.new()
	mat_janela_acesa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_janela_acesa.albedo_color = Color(0.95, 0.82, 0.5)
	mat_janela_acesa.emission_enabled = true
	mat_janela_acesa.emission = Color(0.95, 0.78, 0.45)
	mat_janela_acesa.emission_energy_multiplier = 1.7
	var mat_janela_apagada := StandardMaterial3D.new()
	mat_janela_apagada.albedo_color = Color(0.04, 0.05, 0.08)
	mat_janela_apagada.roughness = 0.2
	mat_janela_apagada.metallic = 0.8
	var quad := BoxMesh.new()
	quad.size = Vector3(1.1, 1.5, 0.1)
	var lados := [
		{"pos": Vector3(0, 0, -h - 10.0), "rot": 0.0, "span": w * 2.0 + 32.0},
		{"pos": Vector3(0, 0, h + 10.0), "rot": PI, "span": w * 2.0 + 32.0},
		{"pos": Vector3(-w - 10.0, 0, 0), "rot": PI * 0.5, "span": h * 2.0 + 32.0},
		{"pos": Vector3(w + 10.0, 0, 0), "rot": -PI * 0.5, "span": h * 2.0 + 32.0},
	]
	for lado in lados:
		var span: float = lado["span"]
		var rot: float = lado["rot"]
		var base: Vector3 = lado["pos"]
		var dir := Vector3(cos(rot), 0.0, sin(rot))   # eixo AO LONGO da fachada
		# Parede do prédio (alta — o teto fica implícito acima do quadro).
		var parede := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(span, 14.0, 1.0)
		parede.mesh = pm
		parede.material_override = mat_fachada
		raiz.add_child(parede)
		parede.position = base + Vector3(0.0, 6.7, 0.0)
		parede.rotation.y = rot
		# Duas fileiras de janelas por fachada (MultiMesh: acesas e apagadas).
		var acesas: Array[Transform3D] = []
		var apagadas: Array[Transform3D] = []
		var n := int(span / 3.0)
		for fileira in 2:
			var y := 4.2 + 3.2 * float(fileira)
			for i in n:
				var off := (float(i) - float(n - 1) * 0.5) * 3.0
				var p := base + dir * off + Vector3(0.0, y, 0.0)
				# Janela levemente à frente da parede (evita z-fighting).
				var recuo := Vector3(sin(rot), 0.0, -cos(rot)) * 0.06
				if base.z > 0.0:
					recuo = Vector3(sin(rot), 0.0, -cos(rot)) * 0.06
				var t := Transform3D(Basis(Vector3.UP, rot), p + recuo * (1.0 if base.z <= 0.0 and absf(base.x) < 0.1 else 1.0))
				if rng.randf() < 0.5:
					acesas.append(t)
				else:
					apagadas.append(t)
		for par in [[acesas, mat_janela_acesa], [apagadas, mat_janela_apagada]]:
			var lista: Array = par[0]
			if lista.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = quad
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = par[1]
			raiz.add_child(mmi)
		# Pilares estruturais na fachada.
		var n_pil := int(span / 12.0)
		for i in n_pil:
			var off2 := (float(i) - float(n_pil - 1) * 0.5) * 12.0
			var pil := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.3, 14.0, 1.6)
			pil.mesh = bm
			pil.material_override = mat_fachada
			raiz.add_child(pil)
			pil.position = base + dir * off2 + Vector3(0.0, 6.7, 0.0)
			pil.rotation.y = rot


## Vigas metálicas no alto — SÓ sobre a moldura (nunca sobre o campo: ocluiriam o
## gameplay) e SEM sombra (não sujam a leitura do ringue). Holofotes pendurados
## mirando os quadrantes (a luz do "torneio clandestino").
func _galpao_vigas_e_holofotes(raiz: Node3D, w: float, h: float, mat_escuro: Material) -> void:
	for zi in [-h - 4.0, -h - 8.5, h + 4.0, h + 8.5]:
		var viga := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w * 2.0 + 24.0, 0.9, 0.7)
		viga.mesh = bm
		viga.material_override = mat_escuro
		viga.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(viga)
		viga.position = Vector3(0.0, 9.5, zi)
	# HOLOFOTE-MESTRE do ringue: um facho largo de cima do centro — o tabuleiro é o
	# palco iluminado, as bordas caem ~30% pelo falloff (escada de brilho, Art Bible §2).
	# Com o fog volumétrico, o cone vira um SHAFT de luz visível (torneio clandestino).
	var mestre := SpotLight3D.new()
	mestre.light_color = Color(1.0, 0.97, 0.9)
	mestre.light_energy = 5.0
	mestre.spot_range = 26.0
	mestre.spot_angle = 60.0
	mestre.spot_angle_attenuation = 1.2
	mestre.shadow_enabled = false
	raiz.add_child(mestre)
	mestre.position = Vector3(0.0, 13.0, 0.0)
	mestre.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var luminaria := MeshInstance3D.new()
	var lum := CylinderMesh.new()
	lum.top_radius = 0.5
	lum.bottom_radius = 0.75
	lum.height = 0.8
	luminaria.mesh = lum
	luminaria.material_override = mat_escuro
	luminaria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(luminaria)
	luminaria.position = Vector3(0.0, 13.2, 0.0)
	# 4 holofotes menores acima dos CANTOS, mirando pra dentro (preenchem os quadrantes).
	var cantos := [Vector3(-w * 0.55, 0, -h * 0.55), Vector3(w * 0.55, 0, -h * 0.55),
			Vector3(-w * 0.55, 0, h * 0.55), Vector3(w * 0.55, 0, h * 0.55)]
	for alvo in cantos:
		var corpo := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.35
		cm.bottom_radius = 0.5
		cm.height = 0.7
		corpo.mesh = cm
		corpo.material_override = mat_escuro
		corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(corpo)
		var pos := (alvo as Vector3) * 1.15 + Vector3(0.0, 9.2, 0.0)
		corpo.position = pos
		var luz := SpotLight3D.new()
		luz.light_color = Color(1.0, 0.95, 0.85)
		luz.light_energy = 1.1
		luz.spot_range = 15.0
		luz.spot_angle = 36.0
		luz.shadow_enabled = false
		raiz.add_child(luz)
		luz.position = pos
		luz.look_at(alvo, Vector3.FORWARD if absf(Vector3.UP.dot(((alvo as Vector3) - pos).normalized())) > 0.99 else Vector3.UP)


## Passarela de manutenção elevada ao longo da fachada norte (com guarda-corpo e
## pilares — regra do encanador: nada flutua).
func _galpao_passarela(raiz: Node3D, w: float, h: float, mat_escuro: Material) -> void:
	var z := -h - 6.5
	var span := w * 2.0 + 20.0
	var deck := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(span, 0.25, 2.4)
	deck.mesh = bm
	deck.material_override = mat_escuro
	raiz.add_child(deck)
	deck.position = Vector3(0.0, 4.6, z)
	for lado_z in [-1.1, 1.1]:
		var grade := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(span, 0.08, 0.06)
		grade.mesh = gm
		grade.material_override = mat_escuro
		raiz.add_child(grade)
		grade.position = Vector3(0.0, 5.6, z + float(lado_z))
	var n_sup := int(span / 7.0)
	for i in n_sup:
		var x := (float(i) - float(n_sup - 1) * 0.5) * 7.0
		var sup := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.35, 4.7, 0.35)
		sup.mesh = sm
		sup.material_override = mat_escuro
		raiz.add_child(sup)
		sup.position = Vector3(x, 2.35, z)
		# Balaústres do guarda-corpo em cima de cada pilar.
		var bal := MeshInstance3D.new()
		var blm := BoxMesh.new()
		blm.size = Vector3(0.08, 1.0, 0.08)
		bal.mesh = blm
		bal.material_override = mat_escuro
		raiz.add_child(bal)
		bal.position = Vector3(x, 5.1, z)


## MOLDURA: geradores com dutos ligados à fachada, containers, tubulação — máquinas
## que parecem operar (regra do encanador).
func _galpao_maquinas(raiz: Node3D, rng: RandomNumberGenerator, w: float, h: float,
		mat_escuro: Material, mat_tema: Material, mat_luz: Material) -> void:
	# Geradores: caixa + topo cilíndrico + LED + DUTO conectando à fachada mais próxima.
	for i in 4:
		var lado_x := -1.0 if i % 2 == 0 else 1.0
		var px := lado_x * (w + rng.randf_range(4.0, 8.0))
		var pz := rng.randf_range(-h * 0.7, h * 0.7)
		var corpo := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.6, 2.0, 3.4)
		corpo.mesh = bm
		corpo.material_override = mat_tema
		raiz.add_child(corpo)
		corpo.position = Vector3(px, 0.7, pz)
		var topo := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.8
		cm.bottom_radius = 0.8
		cm.height = 1.1
		topo.mesh = cm
		topo.material_override = mat_escuro
		raiz.add_child(topo)
		topo.position = Vector3(px, 2.2, pz)
		var led := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.5, 0.12, 0.12)
		led.mesh = lm
		led.material_override = mat_luz
		raiz.add_child(led)
		led.position = Vector3(px - lado_x * 1.31, 1.1, pz)
		# Duto do gerador correndo até a fachada lateral.
		var comp := absf((w + 10.0) - absf(px)) + 1.0
		var duto := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.28
		dm.bottom_radius = 0.28
		dm.height = comp
		duto.mesh = dm
		duto.material_override = mat_escuro
		raiz.add_child(duto)
		duto.rotation.z = PI * 0.5
		duto.position = Vector3(lado_x * (absf(px) + comp * 0.5), 1.9, pz)
	# Containers empilhados (carga do setor).
	for i in 8:
		var lado_z2 := -1.0 if rng.randf() < 0.5 else 1.0
		var px2 := rng.randf_range(-w - 10.0, w + 10.0)
		var pz2 := lado_z2 * (h + rng.randf_range(4.0, 10.0))
		var alt := rng.randf_range(1.7, 2.2)
		var caixa := BoxMesh.new()
		caixa.size = Vector3(rng.randf_range(3.5, 5.0), alt, 2.2)
		var mi := MeshInstance3D.new()
		mi.mesh = caixa
		mi.material_override = mat_tema if rng.randf() < 0.5 else mat_escuro
		raiz.add_child(mi)
		mi.position = Vector3(px2, alt * 0.5 - 0.3, pz2)
		mi.rotation.y = rng.randf_range(-0.2, 0.2)
		if rng.randf() < 0.45:
			var topo2 := MeshInstance3D.new()
			topo2.mesh = caixa
			topo2.material_override = mat_escuro if mi.material_override == mat_tema else mat_tema
			raiz.add_child(topo2)
			topo2.position = mi.position + Vector3(rng.randf_range(-0.3, 0.3), alt, 0.0)
			topo2.rotation.y = mi.rotation.y + rng.randf_range(-0.06, 0.06)
	# Tubulação dupla rente às fachadas leste/oeste.
	for lado in [-1.0, 1.0]:
		for alt_d in [0.45, 1.05]:
			var duto2 := MeshInstance3D.new()
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.3
			cm2.bottom_radius = 0.3
			cm2.height = h * 2.0 + 18.0
			duto2.mesh = cm2
			duto2.material_override = mat_escuro
			raiz.add_child(duto2)
			duto2.rotation.x = PI * 0.5
			duto2.position = Vector3(lado * (w + 8.8), alt_d, 0.0)


## Luzes de emergência vermelhas piscando nos cantos + POEIRA no ar do galpão
## (o lugar respira) + placas "SETOR" nas fachadas.
func _galpao_emergencia_e_ar(raiz: Node3D, w: float, h: float) -> void:
	for canto in [Vector3(-w - 7.0, 3.2, -h - 7.0), Vector3(w + 7.0, 3.2, h + 7.0)]:
		var bulbo := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		bulbo.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.15, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.15, 0.1)
		mat.emission_energy_multiplier = 0.4
		bulbo.material_override = mat
		raiz.add_child(bulbo)
		bulbo.position = canto
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.2, 0.12)
		luz.light_energy = 0.0
		luz.omni_range = 9.0
		luz.shadow_enabled = false
		raiz.add_child(luz)
		luz.position = canto
		var tw := luz.create_tween().set_loops()
		tw.tween_property(luz, "light_energy", 1.4, 0.9).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(mat, "emission_energy_multiplier", 2.2, 0.9)
		tw.tween_property(luz, "light_energy", 0.1, 0.9).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.3, 0.9)
	# Placa do setor nas fachadas norte/sul (Label3D — sinalização burocrática VECTOR).
	var nome_setor := String(_mapa.nome).to_upper() if _mapa != null else "SETOR"
	for dados in [[Vector3(0.0, 8.6, -h - 9.4), 0.0], [Vector3(0.0, 8.6, h + 9.4), PI]]:
		var placa := Label3D.new()
		placa.text = "VECTOR · %s" % nome_setor
		placa.font_size = 220
		placa.pixel_size = 0.02
		placa.modulate = Color(0.95, 0.75, 0.25, 0.85)
		placa.outline_size = 24
		placa.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		raiz.add_child(placa)
		placa.position = dados[0]
		placa.rotation.y = dados[1]
	# Poeira suspensa sobre o campo (partículas lentas, quase invisíveis — ar denso).
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(w, 2.5, h)
	p.direction = Vector3(0.3, 0.1, 0.0)
	p.spread = 20.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var pm := SphereMesh.new()
	pm.radius = 0.03
	pm.height = 0.06
	p.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = Color(0.8, 0.85, 1.0, 0.18)
	p.mesh.surface_set_material(0, pmat)
	raiz.add_child(p)
	p.position.y = 2.0
	p.emitting = true


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
