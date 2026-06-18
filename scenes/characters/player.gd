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

const VELOCIDADE: float = 7.0
const ZONA_MORTA: float = 0.2

const CENA_ARMADILHA := preload("res://scenes/traps/armadilha.tscn")
## Stats (.tres) de cada tipo disponível. Cresce nos próximos blocos da Fase 3.
const STATS := {
	"mina": preload("res://resources/armadilhas/mina.tres"),
	"bomba": preload("res://resources/armadilhas/bomba.tres"),
	"detonador": preload("res://resources/armadilhas/detonador.tres"),
}
## Ordem de ciclo da seleção.
const ORDEM: Array[String] = ["mina", "bomba", "detonador"]

var inventario: Dictionary = {}      # tipo -> quantidade disponível
var selecao: String = "mina"

var _plantar_antes: bool = false
var _detonar_antes: bool = false
var _ciclo_antes: int = 0            # borda de Q/E (-1 prev, +1 next)


func _ready() -> void:
	super._ready()
	for tipo in ORDEM:
		inventario[tipo] = STATS[tipo].inventario_inicial
		inventario_mudou.emit(tipo, inventario[tipo], STATS[tipo].inventario_inicial)
	selecao = "mina"
	selecao_mudou.emit(selecao)


func _physics_process(_delta: float) -> void:
	var dir := _obter_direcao()
	velocity.x = dir.x * VELOCIDADE
	velocity.z = dir.y * VELOCIDADE
	velocity.y = 0.0
	move_and_slide()
	position.y = ALTURA_PISO
	if dir.length() > 0.01:
		var alvo := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, alvo, 0.25)
	_ler_acoes()


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
