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
