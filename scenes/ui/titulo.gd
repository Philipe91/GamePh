extends Control
## Tela de título (GDD 12 / Fase 7). Botão "Jogar" leva à seleção de personagem. Em
## modo de teste/demo (qualquer arg `--…`), pula direto pra seleção (que encaminha à
## arena), mantendo a suíte headless intacta.

const SELECAO := "res://scenes/ui/selecao.tscn"
const UIEstilo := preload("res://scenes/ui/ui_estilo.gd")

var _dif_label: Label = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo-titulo" in args:
		_montar_ui()
		_capturar()
		return
	if "--demo-settings" in args:
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/settings.tscn")
		return
	if "--demo-story" in args:
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/story.tscn")
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
	AudioManager.tocar_musica()   # trilha desde o menu (continua na arena)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 18)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "VAULTBREAKER"
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIEstilo.titulo_glow(titulo)
	caixa.add_child(titulo)
	# Respiração do glow do título (menu vivo, não estático).
	var tw_pulso := titulo.create_tween().set_loops()
	tw_pulso.tween_property(titulo, "modulate", Color(1.12, 1.12, 1.2), 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_pulso.tween_property(titulo, "modulate", Color(0.92, 0.92, 1.0), 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var sub := Label.new()
	sub.text = "arena fighter de armadilhas — VECTOR megacorp"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	caixa.add_child(sub)

	# Fade-in da tela inteira (entrada suave, não "pisca e apareceu"). Pulado nas
	# capturas/demos (a screenshot sairia no meio do fade, lavada).
	if OS.get_cmdline_user_args().is_empty():
		modulate.a = 0.0
		var tw_in := create_tween()
		tw_in.tween_property(self, "modulate:a", 1.0, 0.5)

	# Dificuldade do bot.
	_dif_label = Label.new()
	_dif_label.text = "Dificuldade: Normal"
	_dif_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	_dif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(_dif_label)

	var linha_dif := HBoxContainer.new()
	linha_dif.alignment = BoxContainer.ALIGNMENT_CENTER
	linha_dif.add_theme_constant_override("separation", 8)
	caixa.add_child(linha_dif)
	for d in [["facil", "Fácil"], ["normal", "Normal"], ["dificil", "Difícil"]]:
		var db := Button.new()
		db.text = d[1]
		db.custom_minimum_size = Vector2(120, 38)
		UIEstilo.estilizar_botao(db, Color(0.6, 0.9, 0.6))
		db.pressed.connect(_escolher_dif.bind(String(d[0]), String(d[1])))
		linha_dif.add_child(db)

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

	var story := Button.new()
	story.text = "STORY  (campanha)"
	story.custom_minimum_size = Vector2(320, 44)
	UIEstilo.estilizar_botao(story, Color(0.8, 0.6, 0.3))
	story.pressed.connect(func(): Transicao.ir_para("res://scenes/ui/story.tscn"))
	caixa.add_child(story)

	var settings := Button.new()
	settings.text = "Configurações"
	settings.custom_minimum_size = Vector2(320, 44)
	UIEstilo.estilizar_botao(settings, Color(0.6, 0.6, 0.7))
	settings.pressed.connect(func(): Transicao.ir_para("res://scenes/ui/settings.tscn"))
	caixa.add_child(settings)


func _escolher_dif(chave: String, nome: String) -> void:
	GameManager.dificuldade = chave
	_dif_label.text = "Dificuldade: " + nome


func _jogar(modo: String) -> void:
	GameManager.modo = modo
	GameManager.objetivo = ""       # partida avulsa: sem objetivo especial do Story
	GameManager.story_missao = -1
	_ir_pra_selecao()


func _ir_pra_selecao() -> void:
	Transicao.ir_para(SELECAO)
