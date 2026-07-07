extends CPUParticles3D
## Burst de partículas de explosão (GDD 4 pilar 4 / Fase 7). One-shot: emite e se
## autodestrói. CPUParticles (não GPU) pra renderizar até em máquina fraca / captura.
##
## A "Luz" (OmniLight3D quente) dá o FLASH da explosão: começa forte e apaga num
## decaimento rápido — luz temporária é metade do peso visual de uma explosão.

@onready var luz: OmniLight3D = $Luz


func _ready() -> void:
	add_to_group("fx")
	emitting = true
	# Flash: a luz nasce forte e morre rápido (tween independente do fluxo abaixo).
	if luz != null:
		var tw := create_tween()
		tw.tween_property(luz, "light_energy", 0.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(lifetime + 0.3).timeout
	queue_free()
