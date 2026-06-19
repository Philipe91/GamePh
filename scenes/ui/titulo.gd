extends Control
## Tela de título (GDD 12 / Fase 7). Botão "Jogar" leva à seleção de personagem. Em
## modo de teste/demo (qualquer arg `--…`), pula direto pra seleção (que encaminha à
## arena), mantendo a suíte headless intacta.

const SELECAO := "res://scenes/ui/selecao.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo-titulo" in args:
		_montar_ui()
		_capturar()
		return
	if not args.is_empty():
		_ir_pra_selecao()
		return
	_montar_ui()


func _capturar() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_captura_arena.png")
	get_tree().quit()


func _montar_ui() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.04, 0.05, 0.09)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 18)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "VAULTBREAKER"
	titulo.add_theme_font_size_override("font_size", 56)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(titulo)

	var sub := Label.new()
	sub.text = "arena fighter de armadilhas"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(sub)

	var jogar := Button.new()
	jogar.text = "JOGAR"
	jogar.custom_minimum_size = Vector2(280, 56)
	jogar.pressed.connect(_ir_pra_selecao)
	caixa.add_child(jogar)


func _ir_pra_selecao() -> void:
	get_tree().change_scene_to_file.call_deferred(SELECAO)
