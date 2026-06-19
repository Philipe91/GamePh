extends Area3D
## Esteira (Conveyer Belt — GDD 10): empurra quem está em cima numa direção. O tile
## não aceita armadilha. Não destrói nem dá dano; só desloca.

@export var direcao: Vector3 = Vector3(1, 0, 0)
@export var velocidade: float = 4.0

var coord: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group("esteiras")
	coord = GridManager.world_to_grid(global_position)
	GridManager.definir_tipo_tile(coord, GridManager.TipoTile.ESTEIRA)  # não planta aqui


func _physics_process(delta: float) -> void:
	var d := direcao
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	for corpo in get_overlapping_bodies():
		if corpo is Node3D:
			corpo.global_position += d * velocidade * delta
