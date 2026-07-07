extends StaticBody3D
## Caixa destrutível (GDD 10): Obstacle Box e Bomb Box.
##
## Leva dano de projétil (Area do projétil detecta o corpo) e de explosão de bomba.
## Ao quebrar: "obstaculo" solta um item escondido; "bomba" explode (dano em área e
## detona as Bombas plantadas em volta).

const ITEM := preload("res://scenes/items/item.tscn")

@export var tipo: String = "obstaculo"     # "obstaculo" | "bomba"
@export var item_escondido: String = "healer"  # item solto pela Obstacle Box

const VIDA: float = 20.0
const RAIO_BOMBA: float = 3.0
const DANO_BOMBA: float = 25.0
var _vida: float = VIDA


func _ready() -> void:
	add_to_group("destrutiveis")
	# Caixa é obstáculo: o tile fica sólido pro pathfinding da IA enquanto ela existir.
	var coord := GridManager.world_to_grid(global_position)
	GridManager.marcar_solido(coord, true)
	tree_exiting.connect(func(): GridManager.marcar_solido(coord, false))
	# CONTAINER de suprimentos VECTOR (Briefing §1.4: madeira num complexo cyberpunk
	# = protótipo): metal pintado dessaturado com PBR; a Bomb Box é vermelho-perigo
	# escuro com LED de célula volátil pulsando.
	var mi := get_node_or_null("Malha") as MeshInstance3D
	if mi != null:
		var mat := StandardMaterial3D.new()
		var tex_path := "res://assets/sprites/texturas/MetalPlates006_1K-JPG_Color.jpg"
		if ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path)
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
		var nrm := "res://assets/sprites/texturas/MetalPlates006_1K-JPG_NormalGL.jpg"
		if ResourceLoader.exists(nrm):
			mat.normal_enabled = true
			mat.normal_texture = load(nrm)
			mat.normal_scale = 0.7
		mat.albedo_color = Color(0.5, 0.16, 0.12) if tipo == "bomba" else Color(0.3, 0.33, 0.38)
		mat.metallic = 0.55
		mat.roughness = 0.55
		mi.material_override = mat
	if tipo == "bomba":
		# LED de perigo pulsando: a Bomb Box avisa que é explosiva (leitura à distância).
		var led := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.5, 0.1, 0.1)
		led.mesh = lm
		var matl := StandardMaterial3D.new()
		matl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		matl.albedo_color = Color(1.0, 0.25, 0.15)
		matl.emission_enabled = true
		matl.emission = Color(1.0, 0.25, 0.15)
		matl.emission_energy_multiplier = 1.0
		led.material_override = matl
		add_child(led)
		led.position = Vector3(0.0, 0.4, 0.71)
		var tw := led.create_tween().set_loops()
		tw.tween_property(matl, "emission_energy_multiplier", 2.4, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(matl, "emission_energy_multiplier", 0.5, 0.5).set_trans(Tween.TRANS_SINE)


## Sofre dano (projétil/explosão). `tipo_dano` ignorado; quebra ao zerar a vida.
func receber_dano(qtd: float, _tipo_dano: String = "normal") -> void:
	_vida -= qtd
	if _vida <= 0.0:
		_destruir()


func _destruir() -> void:
	if tipo == "bomba":
		_explodir()
	else:
		_soltar_item()
	queue_free()


func _explodir() -> void:
	add_to_group("explosoes")  # dissolve Plasma que passar (GDD 9)
	for c in get_tree().get_nodes_in_group("combatentes"):
		if is_instance_valid(c) and global_position.distance_to(c.global_position) <= RAIO_BOMBA:
			if c.has_method("receber_dano"):
				c.receber_dano(DANO_BOMBA)
	# Detona as Bombas plantadas em volta (GDD 10).
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if is_instance_valid(a) and a.stats.tipo == "bomba" \
				and global_position.distance_to(a.global_position) <= RAIO_BOMBA \
				and a.has_method("detonar_externamente"):
			a.detonar_externamente()


func _soltar_item() -> void:
	var it := ITEM.instantiate()
	it.tipo = item_escondido
	get_parent().add_child(it)
	it.global_position = global_position + Vector3(0.0, 0.6, 0.0)
