extends Area3D
## Armadilha — base genérica das 6 armadilhas (GDD seção 6). Configurada por um
## StatsArmadilha (.tres); ramifica o comportamento por `stats.tipo`.
##
## Bloco 1 (Fase 3) implementa os tipos explosivos: mina, bomba, detonador + combo.
## cova/painel/gas entram no bloco 2.
##
## Acoplamento solto: NÃO referencia Player/Bot. Detecta corpos pela Area3D e age via
## has_method; acha alvos/combos pelos grupos "combatentes" e "armadilhas".

const StatsArmadilha := preload("res://scripts/stats_armadilha.gd")

## Avisa o dono que a armadilha saiu de jogo (recarrega o inventário do tipo).
signal consumida

enum Estado { ARMANDO, ARMADA, EXPLODIDA }

@export var stats: StatsArmadilha
@export var dono_id: int = 1

## Tile onde foi plantada (pra liberar a ocupação ao sair).
var coord_grid: Vector2i = Vector2i.ZERO
## Direção que o dono olhava ao plantar (usada pelo Painel de Força — bloco 2).
var direcao_plantio: Vector3 = Vector3.FORWARD
## Gatilho cancelado por Caution Mode/desarme (bloco 4).
var desarmada: bool = false

var _estado: int = Estado.ARMANDO
@onready var detector: CollisionShape3D = $Detector
@onready var marca: MeshInstance3D = $Marca


func _ready() -> void:
	add_to_group("armadilhas")
	position.y = 0.1
	_preparar_visual_e_forma()
	body_entered.connect(_ao_corpo_entrar)
	_pintar(Color(1.0, 0.55, 0.1, 0.9), 0.9)  # armando: aviso laranja
	await get_tree().create_timer(stats.tempo_arma).timeout
	if _estado != Estado.ARMANDO:
		return
	_estado = Estado.ARMADA
	_ao_armar()


## Ajusta o raio do gatilho e o tamanho/cor do marcador a partir do Resource.
func _preparar_visual_e_forma() -> void:
	var forma: CylinderShape3D = detector.shape.duplicate()
	forma.radius = maxf(stats.raio_detector, 0.05)  # 0 = não dispara por pisar
	detector.shape = forma
	marca.material_override = marca.material_override.duplicate()
	# Nas armadilhas de área (sem gatilho de pisar), o disco mostra o footprint.
	var r := stats.raio_efeito if stats.raio_detector <= 0.05 else 0.45
	var escala := maxf(r, 0.45) / 0.45
	marca.scale = Vector3(escala, 1.0, escala)


func _ao_armar() -> void:
	# Armada: discreta na cor do tipo (quase invisível pro inimigo — GDD).
	var c := stats.cor
	_pintar(Color(c.r, c.g, c.b, 0.28), 0.25)


func _ao_corpo_entrar(corpo: Node) -> void:
	if _estado != Estado.ARMADA or desarmada:
		return
	if not corpo.has_method("receber_dano"):
		return
	if int(corpo.get("id_jogador")) == dono_id:
		return  # o dono não dispara a própria armadilha ao pisar
	match stats.tipo:
		"mina":
			_detonar()
		# bomba/detonador não disparam por pisar; cova/painel/gas: bloco 2.


## Acionada externamente pelo combo (mina/detonador do MESMO dono no raio — GDD).
func detonar_externamente() -> void:
	if _estado != Estado.ARMADA or desarmada:
		return
	_detonar()


## Acionada pelo dono ao apertar o botão de detonar (Detonador — GDD).
func acionar() -> void:
	if _estado != Estado.ARMADA or desarmada:
		return
	_detonar()


func _detonar() -> void:
	_estado = Estado.EXPLODIDA
	GridManager.remover_armadilha(coord_grid)
	consumida.emit()
	# Combo: mina e detonador acionam as BOMBAS do mesmo dono dentro do raio (GDD).
	if stats.tipo == "mina" or stats.tipo == "detonador":
		_acionar_bombas_no_raio()
	# Dano + knockback em todos os combatentes no raio (inclui o dono — GDD).
	for c in get_tree().get_nodes_in_group("combatentes"):
		if not is_instance_valid(c):
			continue
		if global_position.distance_to(c.global_position) > stats.raio_efeito:
			continue
		if c.has_method("receber_dano"):
			c.receber_dano(stats.dano)
		if stats.knockback > 0.0 and c.has_method("aplicar_empurrao"):
			c.aplicar_empurrao(c.global_position - global_position, stats.knockback)
	_mostrar_explosao()


func _acionar_bombas_no_raio() -> void:
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if a == self or not is_instance_valid(a):
			continue
		if a.dono_id != dono_id or a.stats.tipo != "bomba":
			continue
		if global_position.distance_to(a.global_position) <= stats.raio_efeito:
			a.detonar_externamente()


func _mostrar_explosao() -> void:
	_pintar(Color(1.0, 0.9, 0.4, 1.0), 3.0)
	var e := maxf(stats.raio_efeito, 0.6) / 0.45
	marca.scale = Vector3(e, 1.0, e)
	await get_tree().create_timer(0.35).timeout
	queue_free()


func _pintar(cor: Color, energia: float) -> void:
	var mat: StandardMaterial3D = marca.material_override
	mat.albedo_color = cor
	mat.emission = Color(cor.r, cor.g, cor.b)
	mat.emission_energy_multiplier = energia
