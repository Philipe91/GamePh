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
const VIDA_FUGIR: float = 30.0      # abaixo disso o bot RECUA (kite) em vez de avançar

# Plantio de armadilhas variadas (IA): Cova pra prender quem persegue, Mina no caminho.
const CENA_ARMADILHA := preload("res://scenes/traps/armadilha.tscn")
const TRAPS := {
	"mina": preload("res://resources/armadilhas/mina.tres"),
	"cova": preload("res://resources/armadilhas/cova.tres"),
	"gas": preload("res://resources/armadilhas/gas.tres"),
}
const INTERVALO_PLANTIO: float = 3.5   # tenta plantar a cada 3.5s
const MAX_ARMADILHAS: int = 4          # teto de armadilhas suas no mapa ao mesmo tempo

var _alvo: Node3D = null
var _t_plantio: float = 2.0            # cooldown atual até a próxima tentativa
var _armadilhas_ativas: int = 0


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
	var dist := para.length()
	var vel := velocidade_base * fator_velocidade()  # base do personagem × slow/speed
	# Com pouca vida e o player por perto, RECUA (kite) em vez de avançar.
	var fugindo := healer < VIDA_FUGIR and dist < 11.0

	if dist > DIST_PARAR or fugindo:
		var base := (-para.normalized()) if fugindo else para.normalized()
		var rumo := base + _desvio_de_armadilhas() * PESO_DESVIO  # sempre foge das armadilhas
		if rumo.length() < 0.05:
			rumo = base
		var d := rumo.normalized()
		velocity.x = d.x * vel
		velocity.z = d.z * vel
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if gravidade_ativa:
		if not is_on_floor():
			velocity.y -= GRAVIDADE * delta
		move_and_slide()
	else:
		velocity.y = 0.0
		move_and_slide()
		position.y = ALTURA_PISO
	# Fugindo: encara o player (atira recuando). Senão: olha pra onde anda.
	if fugindo and dist > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-para.x, -para.z), 0.25)
	elif velocity.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 0.2)

	if _t_plantio <= 0.0:
		_plantar_situacional(dist)
	# Atira no player quando está de frente e dentro do alcance (a cadência/recarga limitam).
	if dist < ALCANCE_TIRO and _encara_alvo(para):
		atirar()
	# Tem a Unit (item da Vault) e distância média: carrega a Plasma (GDD 9).
	if tem_unit and plasma_bombs > 0 and dist > 4.0 and dist < ALCANCE_TIRO and not fugindo:
		iniciar_carga_unit()
	# Bem colado: parte pro soco (derruba). O cooldown do soco limita o ritmo.
	if dist < SOCO_ALCANCE:
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


## Escolhe e planta uma armadilha conforme a situação: Cova quando o player está perto
## (prende quem persegue), Mina quando longe (mina o caminho). Reseta o cooldown.
func _plantar_situacional(dist: float) -> void:
	_t_plantio = INTERVALO_PLANTIO
	_plantar("cova" if dist < 6.0 else "mina")


## Compat com testes/demos: planta uma mina no tile atual.
func _tentar_plantar_mina() -> void:
	_t_plantio = INTERVALO_PLANTIO
	_plantar("mina")


## Planta uma armadilha do `tipo` no tile atual. Respeita o teto e tiles ocupados.
func _plantar(tipo: String) -> void:
	if _armadilhas_ativas >= MAX_ARMADILHAS or not TRAPS.has(tipo):
		return
	var coord := GridManager.world_to_grid(global_position)
	if not GridManager.pode_plantar(coord):
		return
	var a := CENA_ARMADILHA.instantiate()
	a.stats = TRAPS[tipo]
	a.dono_id = id_jogador
	a.coord_grid = coord
	get_parent().add_child(a)
	a.global_position = GridManager.grid_to_world(coord)
	GridManager.registrar_armadilha(coord, id_jogador, tipo, a)
	a.consumida.connect(func(): _armadilhas_ativas = maxi(0, _armadilhas_ativas - 1))
	_armadilhas_ativas += 1


## Acha o primeiro combatente de outro time (o player). Sem acoplamento por nome.
func _achar_alvo() -> Node3D:
	for c in get_tree().get_nodes_in_group("combatentes"):
		if c == self:
			continue
		if c.get("id_jogador") != id_jogador:
			return c
	return null
