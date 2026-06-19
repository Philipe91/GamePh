extends Camera3D
## Screenshake — dá peso às explosões (GDD 11 / Fase 7). Entra no grupo "camera" pra ser
## sacudida por call_group("camera", "tremer", intensidade) de qualquer lugar.

const DECAIMENTO: float = 6.0

var _tremor: float = 0.0
var _base: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("camera")
	_base = position


## Pede um tremor de `intensidade` (não encurta um tremor maior já ativo).
func tremer(intensidade: float) -> void:
	_tremor = maxf(_tremor, intensidade)


func em_tremor() -> bool:
	return _tremor > 0.0


func _process(delta: float) -> void:
	if _tremor <= 0.0:
		return
	position = _base + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _tremor
	_tremor = maxf(0.0, _tremor - DECAIMENTO * delta)
	if _tremor <= 0.0:
		position = _base   # volta ao lugar
