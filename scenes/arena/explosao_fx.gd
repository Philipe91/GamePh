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
	# Fumaça espessa subindo (marca das explosões do Trap Gunner original).
	var fumaca := get_node_or_null("Fumaca") as CPUParticles3D
	if fumaca != null:
		fumaca.emitting = true
	# BRASAS: fagulhas incandescentes voando em arco (vendem o "fogo de verdade").
	var brasas := get_node_or_null("Brasas") as CPUParticles3D
	if brasas != null:
		brasas.emitting = true
	# FOGO residual: chamas contínuas no ponto por ~0.9s depois do estouro.
	var chamas := get_node_or_null("Chamas") as CPUParticles3D
	if chamas != null:
		chamas.emitting = true
		# Tween DONO do nó (não SceneTreeTimer global): morre junto com as chamas,
		# sem "Lambda capture freed" quando a explosão é liberada antes dos 0.9s.
		var tw_chamas := chamas.create_tween()
		tw_chamas.tween_interval(0.9)
		tw_chamas.tween_property(chamas, "emitting", false, 0.0)
	# Flash: a luz nasce forte e morre rápido (tween independente do fluxo abaixo).
	if luz != null:
		var tw := create_tween()
		tw.tween_property(luz, "light_energy", 0.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Onda de choque: anel que expande e some (vende o TAMANHO da explosão).
	var onda := get_node_or_null("Onda") as MeshInstance3D
	if onda != null:
		onda.scale = Vector3(0.4, 1.0, 0.4)
		var mat := onda.material_override as StandardMaterial3D
		var tw2 := create_tween()
		tw2.tween_property(onda, "scale", Vector3(5.5, 1.0, 5.5), 0.32) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if mat != null:
			tw2.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.32)
	var dur := lifetime
	if fumaca != null:
		dur = maxf(dur, fumaca.lifetime)
	await get_tree().create_timer(dur + 0.3).timeout
	queue_free()
