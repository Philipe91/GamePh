extends Node3D
## Vault (P.O.D.S. — GDD 8). Ponto do mapa que cospe um item de tempos em tempos.
## Marca o próprio tile como não-plantável e só solta um novo item quando o anterior
## foi pego. Sorteia o tipo com peso (Unit é raro — a arma suprema do FAQ).

const ITEM := preload("res://scenes/items/item.tscn")
const INTERVALO: float = 8.0
## Peso de cada item no sorteio (FAQ: healer/trap comuns, speed/protect médios, Unit raro).
const PESOS: Dictionary = {
	"healer": 3.0,
	"armadilha": 3.0,
	"speed": 2.0,
	"protect": 2.0,
	"unit": 1.0,
}

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
	# Pulso de emissão: mais forte quando há item esperando (o "pisca" do radar do GDD 11).
	var mat := marca.material_override as StandardMaterial3D
	if mat != null:
		var com_item := _item_atual != null and is_instance_valid(_item_atual)
		var base := 1.6 if com_item else 0.6
		mat.emission_energy_multiplier = base + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	if _item_atual != null and is_instance_valid(_item_atual):
		return  # já tem item esperando ser pego; pausa o relógio
	_t -= delta
	if _t <= 0.0:
		_soltar_item()


func _soltar_item() -> void:
	_t = INTERVALO
	var it := ITEM.instantiate()
	it.tipo = _sortear_tipo()
	_idx += 1
	get_parent().add_child(it)
	it.global_position = global_position + Vector3(0.0, 0.6, 0.0)
	_item_atual = it


## Sorteio por peso. Os 2 primeiros drops da partida NÃO podem ser Unit (não dar a arma
## suprema de graça logo de cara — FAQ trata o Unit como prêmio raro).
func _sortear_tipo() -> String:
	var permite_unit := _idx >= 2
	var total := 0.0
	for tipo in PESOS:
		if tipo == "unit" and not permite_unit:
			continue
		total += PESOS[tipo]
	var r := randf() * total
	for tipo in PESOS:
		if tipo == "unit" and not permite_unit:
			continue
		r -= PESOS[tipo]
		if r <= 0.0:
			return tipo
	return "healer"
