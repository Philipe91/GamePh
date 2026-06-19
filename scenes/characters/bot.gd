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
const DESARME_DIST: float = 1.7        # encostou na armadilha do player -> pode desarmar
const DESARME_TEMPO: float = 1.5       # segundos parado desarmando (exposto)
const ITEM_INTERESSE: float = 7.0      # raio pra pegar item por oportunidade
const ITEM_CURA_ALCANCE: float = 16.0  # com pouca vida, corre pro Healer mesmo longe

var _alvo: Node3D = null
var _t_plantio: float = 2.0            # cooldown atual até a próxima tentativa
var _armadilhas_ativas: int = 0

# Parâmetros ajustados pela dificuldade (preenchidos no _ready).
var _intervalo_plantio: float = INTERVALO_PLANTIO
var _max_armadilhas: int = MAX_ARMADILHAS
var _limiar_tiro: float = 0.7          # quão alinhado precisa estar pra atirar (dot)
var _kite: bool = true                 # recua com pouca vida?
var _desarma: bool = true              # desarma armadilhas do player ao encostar?
var _desarmando: Node = null           # armadilha do player sendo desarmada
var _desarme_t: float = 0.0            # tempo restante do desarme


func _ready() -> void:
	super._ready()
	if stats == null:
		velocidade_base = VELOCIDADE   # bot é um pouco mais lento que o player
	_aplicar_dificuldade()


## Ajusta a IA conforme GameManager.dificuldade (G2): frequência de armadilha, mira,
## teto de armadilhas, kite e velocidade.
func _aplicar_dificuldade() -> void:
	match GameManager.dificuldade:
		"facil":
			_intervalo_plantio = INTERVALO_PLANTIO * 1.7
			_max_armadilhas = 2
			_limiar_tiro = 0.92        # só atira bem de frente -> erra mais
			_kite = false              # não foge: mais burro
			_desarma = false           # nem desarma
			velocidade_base *= 0.9
		"dificil":
			_intervalo_plantio = INTERVALO_PLANTIO * 0.6
			_max_armadilhas = 6
			_limiar_tiro = 0.5         # atira mais fácil
			_kite = true
			velocidade_base *= 1.12
		_:                              # normal
			_intervalo_plantio = INTERVALO_PLANTIO
			_max_armadilhas = MAX_ARMADILHAS
			_limiar_tiro = 0.7
			_kite = true


func _physics_process(delta: float) -> void:
	_t_plantio -= delta
	if esta_derrubado():
		velocity = Vector3.ZERO  # knockdown: sem controle até passar
		return
	if esta_imobilizado():
		velocity = Vector3.ZERO  # preso por Cova/Gás, espera passar
		return
	# Desarmando uma armadilha do player (G4): parado e exposto até concluir.
	if _desarmando != null:
		velocity = Vector3.ZERO
		_mover(delta)
		if not is_instance_valid(_desarmando):
			_desarmando = null
		else:
			_desarme_t -= delta
			if _desarme_t <= 0.0:
				_desarmando.remover_por_desarme()   # remove a armadilha do player
				_desarmando = null
		return
	if _alvo == null or not is_instance_valid(_alvo):
		_alvo = _achar_alvo()
	if _alvo == null:
		return
	var para_jog := _alvo.global_position - global_position
	para_jog.y = 0.0
	var dist_jog := para_jog.length()
	# G6: alvo de MOVIMENTO pode ser um item da Vault (corre pro Healer com pouca vida,
	# pega itens próximos por oportunidade). O COMBATE segue mirando no player (para_jog).
	var item := _melhor_item()
	var para := (item.global_position - global_position) if item != null else para_jog
	para.y = 0.0
	var dist := para.length()
	# Encostou numa armadilha do player? Começa a desarmar (se a dificuldade deixa).
	if _desarma:
		var arm := _armadilha_player_proxima(DESARME_DIST)
		if arm != null:
			arm.cancelar_gatilho()        # não dispara enquanto desarma
			_desarmando = arm
			_desarme_t = DESARME_TEMPO
			velocity = Vector3.ZERO
			_mover(delta)
			return
	var vel := velocidade_base * fator_velocidade()  # base do personagem × slow/speed
	# Com pouca vida e o player por perto, RECUA (kite) — mas não se está indo buscar item.
	var fugindo := item == null and _kite and healer < VIDA_FUGIR and dist_jog < 11.0

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
	_mover(delta)
	# Fugindo: encara o player (atira recuando). Senão: olha pra onde anda.
	if fugindo and dist > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-para.x, -para.z), 0.25)
	elif velocity.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 0.2)

	if _t_plantio <= 0.0:
		_plantar_situacional(dist_jog)
	# Atira no player quando está de frente e dentro do alcance (a cadência/recarga limitam).
	if dist_jog < ALCANCE_TIRO and _encara_alvo(para_jog):
		atirar()
	# Tem a Unit (item da Vault) e distância média: carrega a Plasma (GDD 9).
	if tem_unit and plasma_bombs > 0 and dist_jog > 4.0 and dist_jog < ALCANCE_TIRO and not fugindo:
		iniciar_carga_unit()
	# Bem colado: parte pro soco (derruba). O cooldown do soco limita o ritmo.
	if dist_jog < SOCO_ALCANCE:
		socar()


## Melhor item da Vault pra buscar (G6): com pouca vida, vai atrás do Healer (mesmo longe);
## senão pega qualquer item próximo por oportunidade. Null se não vale a pena.
func _melhor_item() -> Node3D:
	var precisa_cura := healer < VIDA_FUGIR
	var melhor: Node3D = null
	var melhor_d := 1.0e9
	for it in get_tree().get_nodes_in_group("itens"):
		if not is_instance_valid(it):
			continue
		var eh_cura := String(it.get("tipo")) == "healer"
		var raio := ITEM_INTERESSE
		if precisa_cura:
			if not eh_cura:
				continue          # com pouca vida só corre pro Healer
			raio = ITEM_CURA_ALCANCE
		var d := global_position.distance_to(it.global_position)
		if d <= raio and d < melhor_d:
			melhor_d = d
			melhor = it
	return melhor


## Reset de round: zera o estado de IA além do reset-base do Combatente.
func reiniciar() -> void:
	super.reiniciar()
	_desarmando = null
	_armadilhas_ativas = 0
	_t_plantio = 2.0
	_alvo = null


## Aplica gravidade (mapas verticais) ou trava a altura (mapas planos) + move_and_slide.
func _mover(delta: float) -> void:
	if gravidade_ativa:
		if not is_on_floor():
			velocity.y -= GRAVIDADE * delta
		move_and_slide()
	else:
		velocity.y = 0.0
		move_and_slide()
		position.y = ALTURA_PISO


## Armadilha do PLAYER mais próxima dentro de `raio`, ou null (pro desarme).
func _armadilha_player_proxima(raio: float) -> Node:
	var melhor: Node = null
	var melhor_d := raio
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a) or int(a.dono_id) == id_jogador:
			continue
		var d := global_position.distance_to(a.global_position)
		if d <= melhor_d:
			melhor_d = d
			melhor = a
	return melhor


## Tomar dano cancela o desarme em andamento e RE-ARMA a armadilha (counterplay do player).
func receber_dano(qtd: float, tipo_dano: String = "normal") -> void:
	super.receber_dano(qtd, tipo_dano)
	if _desarmando != null:
		if is_instance_valid(_desarmando):
			_desarmando.desarmada = false
		_desarmando = null


## True se a frente do bot (-Z) aponta razoavelmente para o alvo (pra não atirar de costas).
func _encara_alvo(para: Vector3) -> bool:
	var frente := -global_transform.basis.z
	frente.y = 0.0
	if frente.length() < 0.01 or para.length() < 0.01:
		return false
	return frente.normalized().dot(para.normalized()) > _limiar_tiro


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
	_t_plantio = _intervalo_plantio
	_plantar("cova" if dist < 6.0 else "mina")


## Compat com testes/demos: planta uma mina no tile atual.
func _tentar_plantar_mina() -> void:
	_t_plantio = _intervalo_plantio
	_plantar("mina")


## Planta uma armadilha do `tipo` no tile atual. Respeita o teto e tiles ocupados.
func _plantar(tipo: String) -> void:
	if _armadilhas_ativas >= _max_armadilhas or not TRAPS.has(tipo):
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
