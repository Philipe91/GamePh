extends "res://scenes/characters/combatente.gd"
## Bot inimigo — vertical slice (bloco 4).
##
## Persegue o player em linha simples (sem pathfinding, sem desviar de armadilha —
## a IA de armadilha vem em fases futuras). Como anda em cima das minas, é ele quem
## faz o loop do slice virar jogo. Herda de Combatente (Healer, dano, knockback).

const VELOCIDADE: float = 5.0       # um pouco mais lento que o player (foge dá certo)
const DIST_PARAR: float = 1.2       # encostou no alvo, para de empurrar
## [decisão noturna 2026-06-18] O bot tem "faro" de armadilha: desvia das armadilhas
## do player que estão a até este raio (m), em vez de pisar burramente. Deixa o jogo
## mais difícil sem precisar do Caution Mode completo na IA (isso fica pra depois).
const RAIO_DESVIO: float = 2.6
const PESO_DESVIO: float = 1.6      # quão forte o desvio entorta a rota até o player
const ALCANCE_TIRO: float = 14.0    # distância máx pra o bot abrir fogo no player

# Plantio simples de minas (GDD 6.4): dá alvo real pro Caution Mode/Desarme do player.
const CENA_ARMADILHA := preload("res://scenes/traps/armadilha.tscn")
const MINA := preload("res://resources/armadilhas/mina.tres")
const INTERVALO_PLANTIO: float = 4.0   # tenta plantar a cada 4s enquanto persegue
const MAX_MINAS: int = 3               # teto de minas suas no mapa ao mesmo tempo

var _alvo: Node3D = null
var _t_plantio: float = 2.0            # cooldown atual até a próxima tentativa
var _minas_ativas: int = 0


func _ready() -> void:
	super._ready()
	if stats == null:
		velocidade_base = VELOCIDADE   # bot é um pouco mais lento que o player


func _physics_process(delta: float) -> void:
	_t_plantio -= delta
	if esta_derrubado():
		velocity = Vector3.ZERO  # knockdown: sem controle até passar
		return
	if esta_imobilizado():
		velocity = Vector3.ZERO  # preso por Cova/Gás, espera passar
		return
	if _alvo == null or not is_instance_valid(_alvo):
		_alvo = _achar_alvo()
	if _alvo == null:
		return
	var para := _alvo.global_position - global_position
	para.y = 0.0
	var vel := velocidade_base * fator_velocidade()  # base do personagem × slow/speed
	if para.length() > DIST_PARAR:
		# Persegue o player, mas entorta a rota pra fugir das armadilhas dele (A1).
		var rumo := para.normalized() + _desvio_de_armadilhas() * PESO_DESVIO
		if rumo.length() < 0.05:
			rumo = para.normalized()
		var d := rumo.normalized()
		velocity.x = d.x * vel
		velocity.z = d.z * vel
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = 0.0
	move_and_slide()
	position.y = ALTURA_PISO
	if velocity.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 0.2)
	if _t_plantio <= 0.0:
		_tentar_plantar_mina()
	# Atira no player quando está de frente e dentro do alcance (a cadência/recarga limitam).
	if para.length() < ALCANCE_TIRO and _encara_alvo(para):
		atirar()
	# Bem colado: parte pro soco (derruba). O cooldown do soco limita o ritmo.
	if para.length() < SOCO_ALCANCE:
		socar()


## True se a frente do bot (-Z) aponta razoavelmente para o alvo (pra não atirar de costas).
func _encara_alvo(para: Vector3) -> bool:
	var frente := -global_transform.basis.z
	frente.y = 0.0
	if frente.length() < 0.01 or para.length() < 0.01:
		return false
	return frente.normalized().dot(para.normalized()) > 0.7


## Soma de empurrões pra LONGE de cada armadilha do player no raio (faro do bot, A1).
## Vetor nulo quando não há nada perto. Mais forte quanto mais perto da armadilha.
func _desvio_de_armadilhas() -> Vector3:
	var desvio := Vector3.ZERO
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a) or int(a.dono_id) == id_jogador:
			continue  # ignora as próprias; só foge das do inimigo (player)
		var delta: Vector3 = global_position - a.global_position
		delta.y = 0.0
		var dist := delta.length()
		if dist > 0.01 and dist < RAIO_DESVIO:
			desvio += delta.normalized() * (1.0 - dist / RAIO_DESVIO)
	return desvio


## Tenta plantar uma mina no tile atual (sem snap fino: usa o tile onde o bot está).
## Respeita o teto de minas e tiles já ocupados. Reseta o cooldown sempre que tenta.
func _tentar_plantar_mina() -> void:
	_t_plantio = INTERVALO_PLANTIO
	if _minas_ativas >= MAX_MINAS:
		return
	var coord := GridManager.world_to_grid(global_position)
	if not GridManager.pode_plantar(coord):
		return
	var a := CENA_ARMADILHA.instantiate()
	a.stats = MINA
	a.dono_id = id_jogador
	a.coord_grid = coord
	get_parent().add_child(a)
	a.global_position = GridManager.grid_to_world(coord)
	GridManager.registrar_armadilha(coord, id_jogador, "mina", a)
	a.consumida.connect(func(): _minas_ativas = maxi(0, _minas_ativas - 1))
	_minas_ativas += 1


## Acha o primeiro combatente de outro time (o player). Sem acoplamento por nome.
func _achar_alvo() -> Node3D:
	for c in get_tree().get_nodes_in_group("combatentes"):
		if c == self:
			continue
		if c.get("id_jogador") != id_jogador:
			return c
	return null
