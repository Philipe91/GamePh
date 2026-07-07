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
var _gas_ativo: bool = false   # Gás: veneno emitido e fazendo efeito na área
@onready var detector: CollisionShape3D = $Detector
@onready var marca: MeshInstance3D = $Marca


## Camadas de render por dono (GDD: a armadilha é INVISÍVEL pro inimigo — essa é a
## alma do Caution Mode). Dono 1 renderiza na camada 11, dono 2 na 12; cada câmera
## corta a camada do adversário (arena configura o cull_mask). O Caution Mode revela
## via marcadores próprios (camada normal), e o Gás ATIVO/explosões voltam à camada
## visível (perigo emitindo todo mundo vê).
const CAMADA_DONO_1: int = 1 << 10   # camada 11
const CAMADA_DONO_2: int = 1 << 11   # camada 12


func _ready() -> void:
	add_to_group("armadilhas")
	position.y = 0.1
	_preparar_visual_e_forma()
	_montar_corpo_3d()
	_aplicar_camada_de_dono()
	body_entered.connect(_ao_corpo_entrar)
	var c0 := stats.cor
	_pintar(Color(c0.r, c0.g, c0.b, 0.9), 0.9)  # armando: brilho na cor do tipo
	await get_tree().create_timer(stats.tempo_arma).timeout
	if _estado != Estado.ARMANDO:
		return
	_estado = Estado.ARMADA
	_ao_armar()


## Esconde o visual do inimigo: marca e corpo vão pra camada exclusiva do dono.
func _aplicar_camada_de_dono() -> void:
	var camada := CAMADA_DONO_1 if dono_id == 1 else CAMADA_DONO_2
	for mi in [marca, get_node_or_null("Corpo")]:
		if mi != null:
			(mi as MeshInstance3D).layers = camada


## Torna o visual VISÍVEL PRA TODOS (gás emitindo, flash de explosão).
func _revelar_para_todos() -> void:
	for mi in [marca, get_node_or_null("Corpo")]:
		if mi != null:
			(mi as MeshInstance3D).layers = 1


## Ajusta o raio do gatilho e o tamanho/cor do marcador a partir do Resource.
func _preparar_visual_e_forma() -> void:
	var forma: CylinderShape3D = detector.shape.duplicate()
	forma.radius = maxf(stats.raio_detector, 0.05)  # 0 = não dispara por pisar
	detector.shape = forma
	marca.material_override = marca.material_override.duplicate()
	# Marcador sempre pequeno e discreto (limpa a tela). O raio só aparece no flash da
	# explosão (_mostrar_explosao) e na nuvem de Gás ativa (_ciclo_gas).
	marca.scale = Vector3.ONE


## Corpo 3D pequeno por tipo em cima do decalque (identidade de silhueta): cúpula da
## mina, esfera da bomba, caixinha do detonador, tambor do gás, aro da cova, seta do
## painel. USA O MESMO material do decalque — some/aparece junto (regras de
## visibilidade intactas: discreta pro inimigo, brilha ao armar/explodir).
func _montar_corpo_3d() -> void:
	var corpo := MeshInstance3D.new()
	corpo.name = "Corpo"
	var y := 0.12
	match stats.tipo:
		"mina":
			var sm := SphereMesh.new()
			sm.radius = 0.24
			sm.height = 0.26   # meia-cúpula saindo do chão
			corpo.mesh = sm
		"bomba":
			var sb := SphereMesh.new()
			sb.radius = 0.3
			sb.height = 0.6
			corpo.mesh = sb
			y = 0.28
		"detonador":
			var bx := BoxMesh.new()
			bx.size = Vector3(0.34, 0.22, 0.34)
			corpo.mesh = bx
			y = 0.11
		"gas":
			var cil := CylinderMesh.new()
			cil.top_radius = 0.22
			cil.bottom_radius = 0.26
			cil.height = 0.34
			corpo.mesh = cil
			y = 0.17
		"cova":
			var tor := TorusMesh.new()
			tor.inner_radius = 0.5
			tor.outer_radius = 0.62
			corpo.mesh = tor
			y = 0.04
		"painel":
			var seta := PrismMesh.new()
			seta.size = Vector3(0.5, 0.08, 0.6)
			corpo.mesh = seta
			y = 0.06
	if corpo.mesh == null:
		corpo.free()
		return
	corpo.material_override = marca.material_override   # fade/brilho junto do decalque
	add_child(corpo)
	corpo.position.y = y
	if stats.tipo == "painel":
		# A seta aponta pra onde o Painel ARREMESSA (direção do plantio).
		var d := direcao_plantio
		d.y = 0.0
		if d.length() > 0.01:
			corpo.rotation.y = atan2(-d.x, -d.z)


func _ao_armar() -> void:
	# Armada: discreta na cor do tipo (quase invisível pro inimigo — GDD).
	var c := stats.cor
	_pintar(Color(c.r, c.g, c.b, 0.28), 0.25)
	if stats.tipo == "gas":
		_ciclo_gas()


func _ao_corpo_entrar(corpo: Node) -> void:
	if not corpo.has_method("receber_dano"):
		return
	# Gás: afeta QUALQUER um que encoste enquanto ativo (inclui o dono — GDD).
	if stats.tipo == "gas":
		if _gas_ativo:
			_aplicar_efeito_gas(corpo)
		return
	if _estado != Estado.ARMADA or desarmada:
		return
	if int(corpo.get("id_jogador")) == dono_id:
		return  # o dono não dispara a própria armadilha ao pisar
	match stats.tipo:
		"mina":
			_detonar()
		"cova":
			corpo.imobilizar(stats.imobiliza)  # prende o inimigo (GDD)
			_consumir(true)
		"painel":
			corpo.aplicar_empurrao(direcao_plantio, stats.arremesso)  # arremessa (GDD)
			_consumir(true)
		# bomba/detonador não disparam por pisar.


## Gás: espera o tempo de emissão, vira veneno ativo por uma duração, depois some.
func _ciclo_gas() -> void:
	await get_tree().create_timer(stats.auto_emite_apos).timeout
	if _estado != Estado.ARMADA or desarmada:
		return
	_gas_ativo = true
	var c := stats.cor
	_pintar(Color(c.r, c.g, c.b, 0.4), 0.6)  # nuvem visível
	_revelar_para_todos()                     # veneno emitindo: TODOS veem a nuvem
	var e := maxf(stats.raio_efeito, 0.6) / 0.45
	marca.scale = Vector3(e, 1.0, e)  # cresce pro raio da nuvem enquanto ativa
	# Pulso inicial em todos que já estão na nuvem.
	for corpo in get_tree().get_nodes_in_group("combatentes"):
		if is_instance_valid(corpo) and global_position.distance_to(corpo.global_position) <= stats.raio_efeito:
			_aplicar_efeito_gas(corpo)
	await get_tree().create_timer(stats.duracao_efeito).timeout
	_gas_ativo = false
	_consumir(false)


func _aplicar_efeito_gas(corpo: Node) -> void:
	if corpo.has_method("receber_dano"):
		corpo.receber_dano(stats.dano)
	if stats.imobiliza > 0.0 and corpo.has_method("imobilizar"):
		corpo.imobilizar(stats.imobiliza)
	if stats.slow_duracao > 0.0 and corpo.has_method("aplicar_slow"):
		corpo.aplicar_slow(stats.slow_fator, stats.slow_duracao)


# ───────────────────────── Desarme e retomada (GDD 6.2 / 6.3) ─────────────────────────

## Encostar em Caution Mode cancela o gatilho da armadilha (GDD 6.2): para de disparar.
func cancelar_gatilho() -> void:
	desarmada = true


## Desarme bem-sucedido pelo inimigo: some sem explodir e libera o tile (recontabiliza).
func remover_por_desarme() -> void:
	_consumir(false)


## Falha no desarme (código errado / tempo / tomou golpe — GDD 6.2):
## explosivas DETONAM; as demais re-armam (voltam a ser perigosas).
func reagir_falha_desarme() -> void:
	desarmada = false
	if stats.tipo == "mina" or stats.tipo == "bomba" or stats.tipo == "detonador":
		_detonar()


## Retomada pelo próprio dono (GDD 6.3): recolhe sem explodir e SEM disparar o reload
## (quem retoma soma +1 no inventário na hora, então não emite `consumida`).
func recolher() -> void:
	if _estado == Estado.EXPLODIDA:
		return
	_estado = Estado.EXPLODIDA
	GridManager.remover_armadilha(coord_grid)
	queue_free()


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
	# Field traps destrutíveis (caixas, lançadores) também levam dano da explosão (GDD 10).
	for d in get_tree().get_nodes_in_group("destrutiveis"):
		if is_instance_valid(d) and global_position.distance_to(d.global_position) <= stats.raio_efeito \
				and d.has_method("receber_dano"):
			d.receber_dano(stats.dano)
	_mostrar_explosao()


## Saída sem explosão (Cova/Painel ao disparar, Gás ao dissipar): libera o tile e some.
func _consumir(com_flash: bool) -> void:
	if _estado == Estado.EXPLODIDA:
		return
	_estado = Estado.EXPLODIDA
	GridManager.remover_armadilha(coord_grid)
	consumida.emit()
	if com_flash:
		_mostrar_explosao()
	else:
		await get_tree().create_timer(0.15).timeout
		queue_free()


func _acionar_bombas_no_raio() -> void:
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if a == self or not is_instance_valid(a):
			continue
		if a.dono_id != dono_id or a.stats.tipo != "bomba":
			continue
		if global_position.distance_to(a.global_position) <= stats.raio_efeito:
			a.detonar_externamente()


func _mostrar_explosao() -> void:
	add_to_group("explosoes")  # a Plasma some ao passar por uma explosão (GDD 9)
	AudioManager.tocar("explodir")
	get_tree().call_group("camera", "tremer", 0.35)  # screenshake (juice)
	GameManager.hit_stop(0.15, 0.05)                 # soluço de impacto (peso — pilar 4)
	var fx := preload("res://scenes/arena/explosao_fx.tscn").instantiate()
	get_parent().add_child(fx)
	fx.global_position = global_position
	_revelar_para_todos()                    # o estouro todo mundo vê
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
