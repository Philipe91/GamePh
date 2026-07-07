extends StaticBody3D
## Lançador de mapa (GDD 10): Laser Launcher e Rocket Launcher. Dispara projéteis num
## intervalo fixo numa direção. Destrutível por projétil ou bomba (group "destrutiveis").
## Os tiros são de "ninguém" (dono_id 0), então acertam os DOIS jogadores.

const PROJETIL := preload("res://scenes/projeteis/projetil.tscn")

@export var tipo: String = "laser"          # "laser" | "foguete"
@export var direcao: Vector3 = Vector3(0, 0, 1)
@export var intervalo: float = 2.0
## Cannon (foguete): só dispara quando um combatente entra neste alcance (em metros).
@export var alcance_proximidade: float = 12.0

const VIDA: float = 15.0
var _vida: float = VIDA
var _t: float = 1.0


func _ready() -> void:
	add_to_group("destrutiveis")
	# Lançador é obstáculo fixo: tile sólido pro pathfinding enquanto existir.
	var coord := GridManager.world_to_grid(global_position)
	GridManager.marcar_solido(coord, true)
	tree_exiting.connect(func(): GridManager.marcar_solido(coord, false))
	# A torreta APONTA o cano pra direção do disparo (leitura de perigo à distância).
	var cabeca := get_node_or_null("Cabeca") as Node3D
	if cabeca != null:
		var d := direcao
		d.y = 0.0
		if d.length() > 0.01:
			cabeca.rotation.y = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	if tipo == "foguete":
		# Cannon: míssil teleguiado, só dispara se houver alguém no alcance (FAQ).
		var alvo := _combatente_no_alcance(alcance_proximidade)
		if alvo != null:
			_disparar_foguete(alvo)
	else:
		_disparar_laser()


## Laser Blaster: tiro reto rápido na direção fixa, em intervalos (FAQ: longo alcance).
func _disparar_laser() -> void:
	_t = intervalo
	var d := direcao
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	var p := PROJETIL.instantiate()
	p.dono_id = 0                  # field trap: acerta os dois times
	p.dano = 8.0
	p.velocidade = d * 22.0
	p.vida = 3.0                   # alcance longo (FAQ)
	get_parent().add_child(p)
	p.global_position = global_position + d * 1.2
	p.global_position.y = 1.0


## Cannon: míssil grande, lento e TELEGUIADO atrás do alvo (dá pra desviar correndo — FAQ).
func _disparar_foguete(alvo: Node) -> void:
	_t = intervalo
	var d: Vector3 = alvo.global_position - global_position
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	var p := PROJETIL.instantiate()
	p.dono_id = 0
	p.dano = 16.0                  # foguete dói mais
	p.velocidade = d * 9.0         # lento: o míssil teleguiado é esquivável
	p.vida = 4.0
	p.teleguiado = true
	p.alvo = alvo
	get_parent().add_child(p)
	p.global_position = global_position + d * 1.2
	p.global_position.y = 1.0


## Combatente mais próximo dentro de `raio`, ou null (proximidade do Cannon).
func _combatente_no_alcance(raio: float) -> Node:
	var melhor: Node = null
	var melhor_d := raio
	for c in get_tree().get_nodes_in_group("combatentes"):
		if not is_instance_valid(c):
			continue
		var dd := global_position.distance_to(c.global_position)
		if dd <= melhor_d:
			melhor_d = dd
			melhor = c
	return melhor


func receber_dano(qtd: float, _tipo_dano: String = "normal") -> void:
	_vida -= qtd
	if _vida <= 0.0:
		queue_free()
