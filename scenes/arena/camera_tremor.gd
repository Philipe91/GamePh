extends Camera3D
## Screenshake — dá peso às explosões (GDD 11 / Fase 7). Entra no grupo "camera" pra ser
## sacudida por call_group("camera", "tremer", intensidade) de qualquer lugar.
##
## O tremor é um OFFSET aplicado por cima da posição atual (e removido no frame
## seguinte), então compõe com a câmera-segue da arena (que move a câmera todo frame).
## A versão antiga restaurava a posição capturada no _ready — em mapa com câmera-segue,
## toda explosão teleportava a câmera de volta pro spawn.

const DECAIMENTO: float = 6.0

var _tremor: float = 0.0
var _offset: Vector3 = Vector3.ZERO   # deslocamento de tremor aplicado no último frame


func _ready() -> void:
	add_to_group("camera")


## Pede um tremor de `intensidade` (não encurta um tremor maior já ativo).
func tremer(intensidade: float) -> void:
	_tremor = maxf(_tremor, intensidade)


func em_tremor() -> bool:
	return _tremor > 0.0


func _process(delta: float) -> void:
	# Remove o offset do frame anterior ANTES de qualquer coisa: a posição "limpa" fica
	# disponível pra quem move a câmera (arena._seguir_player roda no _process dela).
	position -= _offset
	_offset = Vector3.ZERO
	if _tremor <= 0.0:
		return
	_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _tremor
	position += _offset
	_tremor = maxf(0.0, _tremor - DECAIMENTO * delta)
