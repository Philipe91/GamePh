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
	_montar_trail()


## Rastro do projétil: partículas curtas deixadas pelo caminho (coords globais — ficam
## pra trás enquanto o tiro avança). Transforma a esfera num TRACER legível.
func _montar_trail() -> void:
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 0.22
	p.local_coords = false
	p.direction = Vector3.ZERO
	p.spread = 0.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.5
	p.scale_amount_curve = _curva_encolhe()
	p.mesh = SphereMesh.new()
	(p.mesh as SphereMesh).radius = 0.14
	(p.mesh as SphereMesh).height = 0.28
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(cor.r, cor.g, cor.b, 0.55)
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 1.6
	p.mesh.surface_set_material(0, mat)
	add_child(p)
	p.emitting = true


## Curva 1->0: as bolinhas do rastro encolhem até sumir (rastro afinando).
func _curva_encolhe() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


## Estilhaço de IMPACTO no ponto de acerto (alvo ou parede) — o tiro "termina" em algo.
func _fx_impacto() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.3
	p.direction = -velocidade.normalized() if velocidade.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0.0, -6.0, 0.0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.11
	p.mesh = SphereMesh.new()
	(p.mesh as SphereMesh).radius = 0.5
	(p.mesh as SphereMesh).height = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 2.5
	p.mesh.surface_set_material(0, mat)
	p.add_to_group("fx")
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)


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
		# Parede/estrutura: o tiro estilhaça nela em vez de atravessar o cenário.
		if corpo is StaticBody3D:
			_fx_impacto()
			queue_free()
		return
	if int(corpo.get("id_jogador")) == dono_id:
		return  # não acerta quem atirou
	corpo.receber_dano(dano)
	# Míssil/soco-foguete DERRUBAM o alvo (GDD 7.1 — armas teleguiadas knockdown).
	if derruba and corpo.has_method("derrubar"):
		corpo.derrubar(velocidade, DERRUBA_EMPURRAO)
	_fx_impacto()
	queue_free()
