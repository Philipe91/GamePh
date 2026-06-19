extends Node3D
## Vault (P.O.D.S. — GDD 8). Ponto do mapa que cospe um item de tempos em tempos.
## Marca o próprio tile como não-plantável e só solta um novo item quando o anterior
## foi pego. Cicla pelos tipos de item.

const ITEM := preload("res://scenes/items/item.tscn")
const INTERVALO: float = 8.0
const TIPOS: Array[String] = ["healer", "speed", "protect", "armadilha", "unit"]

var coord: Vector2i = Vector2i.ZERO
var _t: float = 3.0           # primeiro item sai mais rápido
var _idx: int = 0
var _item_atual: Node = null

@onready var marca: MeshInstance3D = $Marca


func _ready() -> void:
	add_to_group("vaults")  # aparece no radar (GDD 11)
	coord = GridManager.world_to_grid(global_position)
	GridManager.definir_tipo_tile(coord, GridManager.TipoTile.VAULT)  # não aceita armadilha


func _process(delta: float) -> void:
	if _item_atual != null and is_instance_valid(_item_atual):
		return  # já tem item esperando ser pego; pausa o relógio
	_t -= delta
	if _t <= 0.0:
		_soltar_item()


func _soltar_item() -> void:
	_t = INTERVALO
	var it := ITEM.instantiate()
	it.tipo = TIPOS[_idx % TIPOS.size()]
	_idx += 1
	get_parent().add_child(it)
	it.global_position = global_position + Vector3(0.0, 0.6, 0.0)
	_item_atual = it
