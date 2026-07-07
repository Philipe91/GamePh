extends CanvasLayer
## Menu de pausa (GDD 12 / Fase 7). ESC alterna. Roda mesmo com a árvore pausada
## (process_mode = ALWAYS), senão não dá pra despausar. Menu de verdade: Continuar /
## Voltar ao Menu — não uma label solta.

const UIEstilo := preload("res://scenes/ui/ui_estilo.gd")

@onready var painel: Control = $Painel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	painel.visible = false
	_montar_menu()


## Constrói o conteúdo do painel (título + botões) por cima do escurecedor.
func _montar_menu() -> void:
	var antigo := painel.get_node_or_null("Label")
	if antigo != null:
		antigo.queue_free()   # placeholder da versão antiga
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	painel.add_child(centro)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 16)
	centro.add_child(caixa)
	var titulo := Label.new()
	titulo.text = "PAUSA"
	titulo.add_theme_font_size_override("font_size", 44)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIEstilo.titulo_glow(titulo)
	caixa.add_child(titulo)
	var continuar := Button.new()
	continuar.text = "Continuar"
	continuar.custom_minimum_size = Vector2(280, 48)
	UIEstilo.estilizar_botao(continuar)
	continuar.pressed.connect(alternar)
	caixa.add_child(continuar)
	var sair := Button.new()
	sair.text = "Sair pro menu"
	sair.custom_minimum_size = Vector2(280, 44)
	UIEstilo.estilizar_botao(sair, Color(1.0, 0.45, 0.4))
	sair.pressed.connect(_sair_pro_menu)
	caixa.add_child(sair)
	var dica := Label.new()
	dica.text = "ESC também continua"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_font_size_override("font_size", 14)
	dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	caixa.add_child(dica)


func _sair_pro_menu() -> void:
	get_tree().paused = false
	AudioManager.parar_musica()
	Transicao.ir_para("res://scenes/ui/titulo.tscn")


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):  # ESC
		alternar()


## Liga/desliga a pausa (público pra testes). Mostra/esconde o painel junto.
func alternar() -> void:
	var pausado := not get_tree().paused
	get_tree().paused = pausado
	painel.visible = pausado
