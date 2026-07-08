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

# Plantio de armadilhas (IA). O bot usa o LOADOUT do personagem (.tres) quando tem um —
# cada oponente joga diferente, igual ao Trap Gunner. Sem stats, cai no kit clássico.
const CENA_ARMADILHA := preload("res://scenes/traps/armadilha.tscn")
const TRAPS := {
	"mina": preload("res://resources/armadilhas/mina.tres"),
	"bomba": preload("res://resources/armadilhas/bomba.tres"),
	"detonador": preload("res://resources/armadilhas/detonador.tres"),
	"gas": preload("res://resources/armadilhas/gas.tres"),
	"cova": preload("res://resources/armadilhas/cova.tres"),
	"painel": preload("res://resources/armadilhas/painel.tres"),
}
const KIT_CLASSICO: Array = ["mina", "cova", "gas"]
const INTERVALO_PLANTIO: float = 3.5   # tenta plantar a cada 3.5s
const MAX_ARMADILHAS: int = 4          # teto de armadilhas suas no mapa ao mesmo tempo
const DESARME_DIST: float = 1.7        # encostou na armadilha do player -> pode desarmar
const DESARME_TEMPO: float = 1.5       # segundos parado desarmando (exposto)
const ITEM_INTERESSE: float = 7.0      # raio pra pegar item por oportunidade
const ITEM_CURA_ALCANCE: float = 16.0  # com pouca vida, corre pro Healer mesmo longe

var _alvo: Node3D = null
var _t_plantio: float = 2.0            # cooldown atual até a próxima tentativa
var _armadilhas_ativas: int = 0
var _combo_fase: int = 0               # combo bomba->detonador: 0 = plantar bomba, 1 = detonador
var _t_detonar: float = 0.0            # cooldown do gatilho do combo
var _rota: Array = []                  # waypoints (mundo) do A* até o alvo atual
var _t_rota: float = 0.0               # recalcula a rota a cada 0.5s
var _lado_orbita: float = 1.0          # strafe circular: +1 horário, -1 anti-horário
var _t_orbita: float = 0.0             # troca de lado de tempos em tempos

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
	if esta_derrubado() or esta_imobilizado():
		# Sem controle (knockdown/Cova/Gás), mas o impulso de knockback ainda desliza
		# o corpo (o _mover soma velocidade_impulso — empurrão físico, não teleporte).
		velocity = Vector3.ZERO
		_mover(delta)
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

	# Troca o lado da órbita de tempos em tempos (imprevisível) ou quando bate em algo.
	_t_orbita -= delta
	if _t_orbita <= 0.0 or is_on_wall():
		_t_orbita = randf_range(1.6, 3.2)
		if is_on_wall() or randf() < 0.6:
			_lado_orbita = -_lado_orbita
	if dist > DIST_PARAR or fugindo:
		var base: Vector3
		if fugindo:
			base = -para.normalized()          # fuga: direto pra longe (sem rota)
		elif item == null and dist_jog > 4.5 and dist_jog < 10.5:
			# Média distância: ORBITA o player atirando (strafe circular — não é um
			# zumbi que anda reto na tua cara), com leve aproximação.
			var orbita := para_jog.normalized().cross(Vector3.UP) * _lado_orbita
			base = (orbita * 0.75 + para_jog.normalized() * 0.25).normalized()
		else:
			base = _direcao_pela_rota(para, delta)  # longe: A* contorna caixas
		var rumo := base + _desvio_de_armadilhas() * PESO_DESVIO  # sempre foge das armadilhas
		rumo += _esquiva_de_tiros() * 2.2          # sidestep de projétil vindo
		if rumo.length() < 0.05:
			rumo = base
		var d := rumo.normalized()
		velocity.x = d.x * vel
		velocity.z = d.z * vel
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_mover(delta)
	# Fugindo com o player na cola: solta uma armadilha no caminho do perseguidor
	# (comportamento clássico do Trap Gunner — a fuga vira emboscada).
	if fugindo and _t_plantio <= 0.0 and dist_jog < 9.0:
		_t_plantio = _intervalo_plantio * 0.6
		_plantar("cova" if "cova" in _tipos_disponiveis() else "mina")
	# Combo assinatura: player pisou no raio de uma bomba própria -> ACIONA os detonadores.
	_t_detonar -= delta
	if _t_detonar <= 0.0 and _player_no_raio_de_bomba():
		_t_detonar = 1.5
		_acionar_detonadores_proprios()
	# Em alcance de combate (ou fugindo), ENCARA o player — atira de verdade em vez de
	# dar as costas enquanto orbita. Fora de alcance, olha pra onde anda.
	if (fugindo or dist_jog < ALCANCE_TIRO) and para_jog.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-para_jog.x, -para_jog.z), 1.0 - exp(-10.0 * delta))
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
	_combo_fase = 0
	_t_detonar = 0.0
	_rota.clear()
	_t_rota = 0.0
	_alvo = null


## Aplica gravidade (mapas verticais) ou trava a altura (mapas planos) + move_and_slide.
## Soma o impulso de knockback à velocidade do frame (empurrão físico do Combatente).
func _mover(delta: float) -> void:
	velocity.x += velocidade_impulso().x
	velocity.z += velocidade_impulso().z
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


## Soma de empurrões pra LONGE de cada perigo no raio: armadilhas do player (faro, A1)
## e Spark Bits (dão dano nos dois — a IA não pode parecer burra pisando neles).
func _desvio_de_armadilhas() -> Vector3:
	var desvio := Vector3.ZERO
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a) or int(a.dono_id) == id_jogador:
			continue  # ignora as próprias; só foge das do inimigo (player)
		desvio += _empurrao_de(a.global_position, RAIO_DESVIO)
	for s in get_tree().get_nodes_in_group("spark_bits"):
		if is_instance_valid(s) and not s.esta_morto():
			desvio += _empurrao_de(s.global_position, 3.2)
	return desvio


## Esquiva de projéteis: se um tiro inimigo vem na direção do bot (perto e alinhado),
## empurra pro LADO perpendicular à trajetória — o bot "lê" o tiro e sai da frente.
func _esquiva_de_tiros() -> Vector3:
	for p in get_tree().get_nodes_in_group("projeteis"):
		if not is_instance_valid(p) or int(p.get("dono_id")) == id_jogador:
			continue
		var vel_p: Vector3 = p.get("velocidade")
		if vel_p.length() < 0.1:
			continue
		var para_mim: Vector3 = global_position - p.global_position
		para_mim.y = 0.0
		var dist_p := para_mim.length()
		if dist_p > 7.0 or dist_p < 0.1:
			continue
		if vel_p.normalized().dot(para_mim.normalized()) > 0.85:   # vem na minha direção
			var lado := vel_p.normalized().cross(Vector3.UP)
			# Escolhe o lado que AUMENTA a distância da linha de tiro.
			if lado.dot(para_mim) < 0.0:
				lado = -lado
			return lado
	return Vector3.ZERO


## Vetor unitário-decaído pra longe de `origem` (mais forte quanto mais perto).
func _empurrao_de(origem: Vector3, raio: float) -> Vector3:
	var delta: Vector3 = global_position - origem
	delta.y = 0.0
	var dist := delta.length()
	if dist > 0.01 and dist < raio:
		return delta.normalized() * (1.0 - dist / raio)
	return Vector3.ZERO


## Tipos que este bot pode plantar: o loadout do personagem (cada oponente joga
## diferente — fidelidade ao original), ou o kit clássico sem stats.
func _tipos_disponiveis() -> Array:
	if stats != null and not stats.loadout.is_empty():
		var tipos: Array = []
		for t in stats.loadout.keys():
			if TRAPS.has(t):
				tipos.append(t)
		if not tipos.is_empty():
			return tipos
	return KIT_CLASSICO


## Escolhe e planta conforme a situação (controle de território — FAQ):
## 1) tem bomba+detonador no loadout -> monta o COMBO assinatura (bomba, depois
##    detonador no tile seguinte; o gatilho dispara quando o player pisa perto);
## 2) perto de uma Vault -> nega o ponto com armadilha de pisada;
## 3) player perto -> Cova/Painel (prende/arremessa quem persegue);
## 4) longe -> mina o caminho. Sempre restrito ao que o personagem TEM.
func _plantar_situacional(dist: float) -> void:
	_t_plantio = _intervalo_plantio
	var tipos := _tipos_disponiveis()
	var tem_combo: bool = ("bomba" in tipos) and ("detonador" in tipos) and _desarma
	if tem_combo and (dist > 5.0 or _combo_fase == 1):
		if _combo_fase == 0:
			if _plantar("bomba"):
				_combo_fase = 1
			return
		else:
			if _plantar("detonador"):
				_combo_fase = 0
			return
	if _vault_proxima(3.5) != null:
		_plantar_primeiro(["mina", "bomba", "gas", "cova", "painel"], tipos)
		return
	if dist < 6.0:
		_plantar_primeiro(["cova", "painel", "mina", "gas"], tipos)
	else:
		_plantar_primeiro(["mina", "gas", "cova", "bomba"], tipos)


## Planta o primeiro tipo da preferência que exista no loadout do personagem.
func _plantar_primeiro(preferencia: Array, tipos: Array) -> void:
	for t in preferencia:
		if t in tipos:
			_plantar(t)
			return


## True se o PLAYER está dentro do raio de efeito de uma bomba deste bot (hora do combo).
func _player_no_raio_de_bomba() -> bool:
	if _alvo == null or not is_instance_valid(_alvo):
		return false
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a) or int(a.dono_id) != id_jogador:
			continue
		if a.stats.tipo != "bomba":
			continue
		if _alvo.global_position.distance_to(a.global_position) <= a.stats.raio_efeito * 0.9:
			return true
	return false


## Aciona os próprios Detonadores (fecha o combo — igual ao botão de detonar do player).
func _acionar_detonadores_proprios() -> void:
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a) or int(a.dono_id) != id_jogador:
			continue
		if a.stats.tipo == "detonador" and a.has_method("acionar"):
			a.acionar()


## Direção do próximo waypoint da rota A* até o alvo (recalculada a cada 0.5s).
## Sem rota (mesmo tile, grid bloqueado, alvo fora), cai no rumo direto `para`.
func _direcao_pela_rota(para: Vector3, delta: float) -> Vector3:
	_t_rota -= delta
	if _t_rota <= 0.0:
		_t_rota = 0.5
		_rota = GridManager.caminho_mundo(global_position, global_position + para)
	# Consome waypoints já alcançados (chegou perto: vai pro próximo).
	while not _rota.is_empty():
		var alvo: Vector3 = _rota[0]
		if Vector2(alvo.x - global_position.x, alvo.z - global_position.z).length() < 1.1:
			_rota.pop_front()
		else:
			break
	if _rota.is_empty():
		return para.normalized() if para.length() > 0.01 else Vector3.ZERO
	var d: Vector3 = _rota[0] - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


## Vault mais próxima dentro de `raio`, ou null (pra minar o território dela).
func _vault_proxima(raio: float) -> Node:
	for v in get_tree().get_nodes_in_group("vaults"):
		if is_instance_valid(v) and global_position.distance_to(v.global_position) <= raio:
			return v
	return null


## Compat com testes/demos: planta uma mina no tile atual.
func _tentar_plantar_mina() -> void:
	_t_plantio = _intervalo_plantio
	_plantar("mina")


## Planta uma armadilha do `tipo` no tile atual. Respeita o teto e tiles ocupados.
## Retorna true se plantou (o combo usa isso pra avançar de fase).
func _plantar(tipo: String) -> bool:
	if _armadilhas_ativas >= _max_armadilhas or not TRAPS.has(tipo):
		return false
	var coord := GridManager.world_to_grid(global_position)
	if not GridManager.pode_plantar(coord):
		return false
	var a := CENA_ARMADILHA.instantiate()
	a.stats = TRAPS[tipo]
	a.dono_id = id_jogador
	a.coord_grid = coord
	get_parent().add_child(a)
	a.global_position = GridManager.grid_to_world(coord)
	GridManager.registrar_armadilha(coord, id_jogador, tipo, a)
	# Método (não lambda): se o bot morrer antes da armadilha, a conexão some junto.
	a.consumida.connect(_ao_armadilha_consumida)
	_armadilhas_ativas += 1
	animar_plantio()   # mesmo gesto do player (o bot também "trabalha")
	return true


func _ao_armadilha_consumida() -> void:
	_armadilhas_ativas = maxi(0, _armadilhas_ativas - 1)


## Acha o primeiro combatente de outro time (o player). Sem acoplamento por nome.
func _achar_alvo() -> Node3D:
	for c in get_tree().get_nodes_in_group("combatentes"):
		if c == self:
			continue
		if c.get("id_jogador") != id_jogador:
			return c
	return null
