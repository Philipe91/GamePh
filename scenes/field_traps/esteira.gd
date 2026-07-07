extends Area3D
## Esteira (Conveyer Belt — GDD 10): empurra quem está em cima numa direção. O tile
## não aceita armadilha. Não destrói nem dá dano; só desloca.

@export var direcao: Vector3 = Vector3(1, 0, 0)
@export var velocidade: float = 4.0

var coord: Vector2i = Vector2i.ZERO
var _faixas: Array[MeshInstance3D] = []   # barras que deslizam (a "correia" andando)
var _fase: float = 0.0


func _ready() -> void:
	add_to_group("esteiras")
	coord = GridManager.world_to_grid(global_position)
	GridManager.definir_tipo_tile(coord, GridManager.TipoTile.ESTEIRA)  # não planta aqui
	_montar_faixas()


## Barras claras transversais que DESLIZAM na direção do empurrão — sem isso a esteira
## era um quadrado azul parado (playtest reclamou da leitura).
func _montar_faixas() -> void:
	var d := direcao
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	# CHEVRONS âmbar (setas industriais) deslizando na direção do empurrão — a esteira
	# lê como maquinário, não como faixa de pedestre.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.72, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.1)
	mat.emission_energy_multiplier = 1.1
	for i in 3:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(1.1, 0.5, 0.05)
		mi.mesh = pm
		mi.material_override = mat
		mi.rotation.x = -PI * 0.5                       # deitado no chão, ponta pra -Z
		mi.rotation.y = atan2(-d.x, -d.z)               # ponta pra DIREÇÃO do empurrão
		add_child(mi)
		_faixas.append(mi)


func _process(delta: float) -> void:
	if _faixas.is_empty():
		return
	var d := direcao
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	_fase = fmod(_fase + delta * velocidade * 0.35, 1.0)
	for i in _faixas.size():
		var t := fmod(_fase + float(i) / 3.0, 1.0)          # 0..1 ao longo do tile
		_faixas[i].position = d * lerpf(-0.85, 0.85, t) + Vector3(0.0, 0.12, 0.0)


func _physics_process(delta: float) -> void:
	var d := direcao
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	for corpo in get_overlapping_bodies():
		if corpo is Node3D:
			corpo.global_position += d * velocidade * delta
