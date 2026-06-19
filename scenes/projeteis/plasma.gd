extends Area3D
## Plasma Bomb — projétil teleguiado da Unit, o super (GDD 9).
##
## Persegue o inimigo e causa dano massivo (dobrado se o alvo está derrubado). Some ao
## acertar, ao expirar, ou ao passar perto de uma explosão (uma das evasões do GDD 9).

var dono_id: int = 1
var dano: float = 40.0
var alvo: Node = null

const RAPIDEZ: float = 8.0
const VIDA: float = 6.0
const MULT_DERRUBADO: float = 2.0   # dano massivo em alvo derrubado (GDD 7.2)
const RAIO_EXPLOSAO: float = 2.5    # some se uma explosão chegar a esta distância
var _t: float = 0.0


func _ready() -> void:
	add_to_group("plasmas")
	body_entered.connect(_ao_corpo_entrar)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= VIDA:
		queue_free()
		return
	# Evasão (GDD 9): provocar uma explosão no caminho dissolve a Plasma.
	for e in get_tree().get_nodes_in_group("explosoes"):
		if is_instance_valid(e) and global_position.distance_to(e.global_position) < RAIO_EXPLOSAO:
			queue_free()
			return
	# Evasão (GDD 9): atingir uma ponte/passarela dissolve a Plasma e quebra a ponte.
	for pt in get_tree().get_nodes_in_group("pontes"):
		if is_instance_valid(pt) and global_position.distance_to(pt.global_position) < RAIO_EXPLOSAO:
			if pt.has_method("quebrar"):
				pt.quebrar()
			queue_free()
			return
	if alvo == null or not is_instance_valid(alvo):
		alvo = _achar_inimigo()
	if alvo != null:
		var dir: Vector3 = alvo.global_position - global_position
		dir.y = 0.0
		if dir.length() > 0.01:
			global_position += dir.normalized() * RAPIDEZ * delta
	global_position.y = 1.0


func _ao_corpo_entrar(corpo: Node) -> void:
	if not corpo.has_method("receber_dano") or int(corpo.get("id_jogador")) == dono_id:
		return
	var d := dano
	if corpo.has_method("esta_derrubado") and corpo.esta_derrubado():
		d *= MULT_DERRUBADO
	corpo.receber_dano(d, "plasma")  # "plasma" fura o Protect (GDD 8)
	queue_free()


func _achar_inimigo() -> Node:
	for c in get_tree().get_nodes_in_group("combatentes"):
		if is_instance_valid(c) and int(c.get("id_jogador")) != dono_id:
			return c
	return null
