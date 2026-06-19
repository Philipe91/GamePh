extends Control
## Tela de título (GDD 12 / Fase 7). Botão "Jogar" leva à seleção de personagem. Em
## modo de teste/demo (qualquer arg `--…`), pula direto pra seleção (que encaminha à
## arena), mantendo a suíte headless intacta.

const SELECAO := "res://scenes/ui/selecao.tscn"
const UIEstilo := preload("res://scenes/ui/ui_estilo.gd")


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
	UIEstilo.fundo_neon(self)

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
	UIEstilo.titulo_glow(titulo)
	caixa.add_child(titulo)

	var sub := Label.new()
	sub.text = "arena fighter de armadilhas"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(sub)

	var vs_com := Button.new()
	vs_com.text = "VS COM  (contra o bot)"
	vs_com.custom_minimum_size = Vector2(320, 52)
	UIEstilo.estilizar_botao(vs_com)
	vs_com.pressed.connect(_jogar.bind("vs_com"))
	caixa.add_child(vs_com)

	var vs_man := Button.new()
	vs_man.text = "VS MAN  (2 jogadores)"
	vs_man.custom_minimum_size = Vector2(320, 52)
	UIEstilo.estilizar_botao(vs_man, Color(1.0, 0.35, 0.4))
	vs_man.pressed.connect(_jogar.bind("vs_man"))
	caixa.add_child(vs_man)


func _jogar(modo: String) -> void:
	GameManager.modo = modo
	_ir_pra_selecao()


func _ir_pra_selecao() -> void:
	get_tree().change_scene_to_file.call_deferred(SELECAO)
