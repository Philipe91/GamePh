extends "res://scenes/characters/combatente.gd"
## Player — personagem jogável.
##
## Herda de Combatente (Healer, dano, knockback, grupo). Aqui fica o movimento LIVRE
## (WASD + analógico) e o sistema de armadilhas: inventário por TIPO, seleção da ativa
## e plantio com snap no tile (GDD seção 6). A seleção por menu radial entra no bloco 3;
## por ora troca-se com Q/E (teclado) só pra testar os tipos.

## Inventário de um tipo mudou (pra HUD).
signal inventario_mudou(tipo: String, atual: int, maximo: int)
## Armadilha selecionada mudou (pra HUD).
signal selecao_mudou(tipo: String)
## Caution Mode ligou/desligou (pra HUD/áudio — comunicação por signal).
signal caution_mudou(ativo: bool)

const VELOCIDADE: float = 7.0
const ZONA_MORTA: float = 0.2
## Alcance do Caution Mode em tiles (raio). 2 tiles cobrem uma vizinhança 5x5 (GDD 6.1).
const ALCANCE_CAUTION_TILES: float = 2.0

const CENA_ARMADILHA := preload("res://scenes/traps/armadilha.tscn")
## Stats (.tres) de cada tipo disponível. Cresce nos próximos blocos da Fase 3.
const STATS := {
	"mina": preload("res://resources/armadilhas/mina.tres"),
	"bomba": preload("res://resources/armadilhas/bomba.tres"),
	"detonador": preload("res://resources/armadilhas/detonador.tres"),
	"gas": preload("res://resources/armadilhas/gas.tres"),
	"cova": preload("res://resources/armadilhas/cova.tres"),
	"painel": preload("res://resources/armadilhas/painel.tres"),
}
## Ordem de ciclo da seleção (as 6 armadilhas — GDD seção 6).
const ORDEM: Array[String] = ["mina", "bomba", "detonador", "gas", "cova", "painel"]

var inventario: Dictionary = {}      # tipo -> quantidade disponível
var selecao: String = "mina"

var _plantar_antes: bool = false
var _detonar_antes: bool = false
var _ciclo_antes: int = 0            # borda de Q/E (-1 prev, +1 next)

# Caution Mode (GDD 6.1): segurar pra revelar a teia inimiga no alcance.
var _caution_ativo: bool = false
var _caution_no: Node3D = null               # container das malhas do overlay (em mundo)
var _caution_tiles: Array[MeshInstance3D] = []   # pool de destaques de tile (azul)
var _caution_marcas: Array[MeshInstance3D] = []  # pool de marcadores de armadilha (amarelo)


func _ready() -> void:
	super._ready()
	for tipo in ORDEM:
		inventario[tipo] = STATS[tipo].inventario_inicial
		inventario_mudou.emit(tipo, inventario[tipo], STATS[tipo].inventario_inicial)
	selecao = "mina"
	selecao_mudou.emit(selecao)
	_construir_overlay_caution()


var _escape_antes: bool = false      # borda do "mash" pra sair da Cova


func _physics_process(_delta: float) -> void:
	var dir := _obter_direcao()
	if esta_imobilizado():
		# Preso (Cova/Gás): não anda; apertar direção repetidamente acelera a saída.
		velocity = Vector3.ZERO
		var mash := dir.length() > 0.01
		if mash and not _escape_antes:
			tentar_escapar(0.3)
		_escape_antes = mash
	else:
		_escape_antes = false
		var vel := VELOCIDADE * fator_velocidade()  # slow do Gás reduz a velocidade
		velocity.x = dir.x * vel
		velocity.z = dir.y * vel
		velocity.y = 0.0
		move_and_slide()
		position.y = ALTURA_PISO
		if dir.length() > 0.01:
			var alvo := atan2(-velocity.x, -velocity.z)
			rotation.y = lerp_angle(rotation.y, alvo, 0.25)
	_ler_acoes()
	_ler_caution()
	_atualizar_overlay_caution()


func _obter_direcao() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	var gx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var gy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(gx) > ZONA_MORTA:
		dir.x += gx
	if absf(gy) > ZONA_MORTA:
		dir.y += gy
	return dir.limit_length(1.0)


## Lê plantar (Espaço/A), detonar (F/B) e ciclar seleção (Q/E), todos por borda.
func _ler_acoes() -> void:
	var plantar_p := Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if plantar_p and not _plantar_antes:
		plantar()
	_plantar_antes = plantar_p

	var detonar_p := Input.is_physical_key_pressed(KEY_F) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	if detonar_p and not _detonar_antes:
		acionar_detonadores()
	_detonar_antes = detonar_p

	var ciclo := 0
	if Input.is_physical_key_pressed(KEY_E):
		ciclo = 1
	elif Input.is_physical_key_pressed(KEY_Q):
		ciclo = -1
	if ciclo != 0 and _ciclo_antes == 0:
		trocar_selecao(ciclo)
	_ciclo_antes = ciclo


## Troca a armadilha selecionada (passo +1/-1 na ORDEM).
func trocar_selecao(passo: int) -> void:
	var i := ORDEM.find(selecao)
	i = (i + passo + ORDEM.size()) % ORDEM.size()
	selecao = ORDEM[i]
	selecao_mudou.emit(selecao)


## Planta a armadilha do tipo dado (ou a selecionada). Faz snap no tile. Retorna true.
func plantar(tipo: String = "") -> bool:
	if tipo == "":
		tipo = selecao
	if int(inventario.get(tipo, 0)) <= 0:
		return false
	var coord := GridManager.world_to_grid(global_position)
	if not GridManager.pode_plantar(coord):
		return false
	var a := CENA_ARMADILHA.instantiate()
	a.stats = STATS[tipo]
	a.dono_id = id_jogador
	a.coord_grid = coord
	a.direcao_plantio = -global_transform.basis.z  # frente atual (pro Painel)
	get_parent().add_child(a)
	a.global_position = GridManager.grid_to_world(coord)
	GridManager.registrar_armadilha(coord, id_jogador, tipo, a)
	a.consumida.connect(_ao_armadilha_consumida.bind(tipo))
	inventario[tipo] = int(inventario[tipo]) - 1
	inventario_mudou.emit(tipo, inventario[tipo], STATS[tipo].inventario_inicial)
	return true


## Aciona todos os Detonadores armados deste jogador (botão de detonar).
func acionar_detonadores() -> void:
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a):
			continue
		if a.dono_id == id_jogador and a.stats.tipo == "detonador" and a.has_method("acionar"):
			a.acionar()


## Recarrega 1 unidade do tipo após o tempo de retorno (GDD).
func _ao_armadilha_consumida(tipo: String) -> void:
	await get_tree().create_timer(STATS[tipo].tempo_retorno).timeout
	inventario[tipo] = mini(int(inventario[tipo]) + 1, int(STATS[tipo].inventario_inicial))
	inventario_mudou.emit(tipo, inventario[tipo], STATS[tipo].inventario_inicial)


# ───────────────────────────── Caution Mode (GDD 6.1) ─────────────────────────────

## Raio do Caution Mode em unidades de mundo.
func raio_caution() -> float:
	return ALCANCE_CAUTION_TILES * GridManager.TAMANHO_TILE


func caution_ativo() -> bool:
	return _caution_ativo


## Liga/desliga manualmente (input em jogo; setter direto nos testes/IA).
func ativar_caution(v: bool) -> void:
	if v == _caution_ativo:
		return
	_caution_ativo = v
	caution_mudou.emit(_caution_ativo)


## Coords das armadilhas inimigas reveladas agora (vazio fora do Caution Mode).
func armadilhas_detectadas() -> Array[Vector2i]:
	if not _caution_ativo:
		return []
	return GridManager.armadilhas_inimigas_no_raio(id_jogador, global_position, raio_caution())


## Lê o botão de Caution (segurar C / L1). Estado contínuo, não por borda — anda segurando.
func _ler_caution() -> void:
	var segurando := Input.is_physical_key_pressed(KEY_C) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
	ativar_caution(segurando)


## Monta os pools de malhas do overlay uma vez (highlights de tile + marcadores), ocultos.
## Ficam no PAI (mundo), não como filhos do player, pra não girar/transladar com a cápsula.
func _construir_overlay_caution() -> void:
	_caution_no = Node3D.new()
	_caution_no.name = "OverlayCaution"
	# Filho do player, mas top_level: vive em espaço de MUNDO (não gira/transla com a
	# cápsula). Anexar a si mesmo evita o "parent busy" de mexer no pai durante o _ready.
	_caution_no.top_level = true
	add_child(_caution_no)

	# Pool de destaques de tile (azul translúcido, deitado no chão).
	var lado := GridManager.TAMANHO_TILE * 0.92
	var mat_tile := StandardMaterial3D.new()
	mat_tile.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_tile.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_tile.albedo_color = Color(0.1, 0.55, 1.0, 0.22)
	mat_tile.emission_enabled = true
	mat_tile.emission = Color(0.1, 0.55, 1.0)
	mat_tile.emission_energy_multiplier = 0.3
	for _i in range(25):  # 5x5 = teto de tiles no raio de 2
		var plano := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(lado, lado)
		plano.mesh = pm
		plano.material_override = mat_tile
		plano.visible = false
		_caution_no.add_child(plano)
		_caution_tiles.append(plano)

	# Pool de marcadores de armadilha detectada (amarelo, flutuando acima — GDD seção 12).
	var mat_marca := StandardMaterial3D.new()
	mat_marca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_marca.albedo_color = Color(1.0, 0.85, 0.1)
	mat_marca.emission_enabled = true
	mat_marca.emission = Color(1.0, 0.85, 0.1)
	mat_marca.emission_energy_multiplier = 2.0
	for _i in range(12):
		var marca := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.28
		sm.height = 0.56
		marca.mesh = sm
		marca.material_override = mat_marca
		marca.visible = false
		_caution_no.add_child(marca)
		_caution_marcas.append(marca)


## Mostra os tiles no alcance (azul) e um marcador sobre cada armadilha inimiga detectada.
func _atualizar_overlay_caution() -> void:
	if _caution_no == null:
		return
	if not _caution_ativo:
		if _caution_no.visible:
			_caution_no.visible = false
		return
	_caution_no.visible = true

	var centro := GridManager.world_to_grid(global_position)
	var raio := raio_caution()
	var alc := int(ceil(ALCANCE_CAUTION_TILES))
	var usados := 0
	for dx in range(-alc, alc + 1):
		for dy in range(-alc, alc + 1):
			if usados >= _caution_tiles.size():
				break
			var coord := centro + Vector2i(dx, dy)
			if not GridManager.dentro_do_grid(coord):
				continue
			var p := GridManager.grid_to_world(coord)
			if Vector2(p.x - global_position.x, p.z - global_position.z).length() > raio:
				continue
			var plano := _caution_tiles[usados]
			plano.global_position = Vector3(p.x, 0.05, p.z)  # acima das linhas do grid
			plano.visible = true
			usados += 1
	for i in range(usados, _caution_tiles.size()):
		_caution_tiles[i].visible = false

	# Marcadores sobre as armadilhas inimigas no alcance.
	var inimigas := GridManager.armadilhas_inimigas_no_raio(id_jogador, global_position, raio)
	var m := 0
	for coord in inimigas:
		if m >= _caution_marcas.size():
			break
		var p := GridManager.grid_to_world(coord)
		var marca := _caution_marcas[m]
		marca.global_position = Vector3(p.x, 1.4, p.z)
		marca.visible = true
		m += 1
	for i in range(m, _caution_marcas.size()):
		_caution_marcas[i].visible = false
