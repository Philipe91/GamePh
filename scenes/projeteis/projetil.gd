extends Area3D
## Projétil — tiro reto da arma à distância (GDD 7.1).
##
## Anda em linha reta, vive um tempo curto e some ao acertar um combatente de outro
## time ou ao expirar. Acoplamento solto: acha alvo por `has_method("receber_dano")` e
## ignora o próprio dono pelo `id_jogador`.

var dono_id: int = 1
var dano: float = 12.0
var velocidade: Vector3 = Vector3.ZERO   # direção * rapidez (m/s), no plano XZ

const VIDA: float = 2.0   # segundos até sumir sozinho (alcance efetivo)
var _t: float = 0.0


func _ready() -> void:
	add_to_group("projeteis")
	body_entered.connect(_ao_corpo_entrar)


func _physics_process(delta: float) -> void:
	global_position += velocidade * delta
	global_position.y = 1.0
	_t += delta
	if _t >= VIDA:
		queue_free()


func _ao_corpo_entrar(corpo: Node) -> void:
	if not corpo.has_method("receber_dano"):
		return
	if int(corpo.get("id_jogador")) == dono_id:
		return  # não acerta quem atirou
	corpo.receber_dano(dano)
	queue_free()
