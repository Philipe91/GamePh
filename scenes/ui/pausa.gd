extends CanvasLayer
## Menu de pausa (GDD 12 / Fase 7). ESC alterna pausa. Roda mesmo com a árvore pausada
## (process_mode = ALWAYS), senão não dá pra despausar.

@onready var painel: Control = $Painel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	painel.visible = false


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):  # ESC
		alternar()


## Liga/desliga a pausa (público pra testes). Mostra/esconde o painel junto.
func alternar() -> void:
	var pausado := not get_tree().paused
	get_tree().paused = pausado
	painel.visible = pausado
