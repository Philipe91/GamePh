extends Area3D
## Projétil — tiro reto da arma à distância (GDD 7.1).
##
## Anda em linha reta, vive um tempo curto e some ao acertar um combatente de outro
## time ou ao expirar. Acoplamento solto: acha alvo por `has_method("receber_dano")` e
## ignora o próprio dono pelo `id_jogador`.

var dono_id: int = 1
var dano: float = 12.0
var velocidade: Vector3 = Vector3.ZERO   # direção * rapidez (m/s), no plano XZ
## Identidade visual da arma (cor do projétil + luz) e knockdown ao acertar.
var cor: Color = Color(1.0, 0.9, 0.35)
var derruba: bool = false
const DERRUBA_EMPURRAO: float = 2.5

## Teleguiado (Cannon do Trap Gunner): se `teleguiado` e há `alvo`, o míssil curva atrás
## dele com giro limitado (dá pra desviar correndo). Default é reto (alvo nulo).
var teleguiado: bool = false
var alvo: Node = null
const GIRO_TELEGUIADO: float = 2.6   # rad/s do giro do míssil (baixo = esquivável)

@export var vida: float = 2.0   # segundos até sumir sozinho (alcance efetivo)
var _t: float = 0.0


func _ready() -> void:
	add_to_group("projeteis")
	body_entered.connect(_ao_corpo_entrar)
	# Tiro "de verdade": projétil na COR da arma + luz própria (o glow do ambiente
	# transforma isso num tracer). Cada arma fica reconhecível na tela.
	var mi := get_node_or_null("Malha") as MeshInstance3D
	if mi != null and mi.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mi.material_override.duplicate()
		mat.albedo_color = cor
		mat.emission = cor
		mat.emission_energy_multiplier = 3.5
		mi.material_override = mat
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.4
	luz.omni_range = 3.0
	luz.shadow_enabled = false
	add_child(luz)


func _physics_process(delta: float) -> void:
	if teleguiado and is_instance_valid(alvo):
		var para: Vector3 = alvo.global_position - global_position
		para.y = 0.0
		var rapidez := velocidade.length()
		if para.length() > 0.01 and rapidez > 0.01:
			var nova := velocidade.normalized().slerp(para.normalized(), clampf(GIRO_TELEGUIADO * delta, 0.0, 1.0))
			velocidade = nova * rapidez
	global_position += velocidade * delta
	global_position.y = 1.0
	_t += delta
	if _t >= vida:
		queue_free()


func _ao_corpo_entrar(corpo: Node) -> void:
	if not corpo.has_method("receber_dano"):
		return
	if int(corpo.get("id_jogador")) == dono_id:
		return  # não acerta quem atirou
	corpo.receber_dano(dano)
	# Míssil/soco-foguete DERRUBAM o alvo (GDD 7.1 — armas teleguiadas knockdown).
	if derruba and corpo.has_method("derrubar"):
		corpo.derrubar(velocidade, DERRUBA_EMPURRAO)
	queue_free()
