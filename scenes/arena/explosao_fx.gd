extends CPUParticles3D
## Burst de partículas de explosão (GDD 4 pilar 4 / Fase 7). One-shot: emite e se
## autodestrói. CPUParticles (não GPU) pra renderizar até em máquina fraca / captura.

func _ready() -> void:
	add_to_group("fx")
	emitting = true
	await get_tree().create_timer(lifetime + 0.3).timeout
	queue_free()
