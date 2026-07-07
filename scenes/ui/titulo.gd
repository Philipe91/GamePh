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
	_montar_vitrine_3d()          # personagem 3D vivo ao lado do menu (background vivo)
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


## Vitrine 3D no menu: um personagem do roster (aleatório por sessão) em idle armado,
## girando devagar num pedestal, com luz própria — o menu deixa de ser só texto.
func _montar_vitrine_3d() -> void:
	var roster := ["brecht", "magnus", "vesna", "pip", "kestrel", "mara"]
	var st: Resource = load("res://resources/personagens/%s.tres" % roster[randi() % roster.size()])
	if st == null or st.cena_modelo == null:
		return
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	cont.offset_left = -330.0
	cont.offset_right = 10.0
	cont.offset_top = -240.0
	cont.offset_bottom = 240.0
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(vp)
	var raiz := Node3D.new()
	vp.add_child(raiz)
	var m: Node3D = st.cena_modelo.instantiate()
	raiz.add_child(m)
	m.position = Vector3(0.0, -1.05, 0.0)
	# Idle armado em loop.
	var anims := m.find_children("*", "AnimationPlayer", true, false)
	if not anims.is_empty():
		var ap := anims[0] as AnimationPlayer
		for nome_anim in ["Idle_Gun", "Idle"]:
			if ap.has_animation(nome_anim):
				var a := ap.get_animation(nome_anim)
				a.loop_mode = Animation.LOOP_LINEAR
				ap.play(nome_anim)
				break
	# Pedestal com aro na cor do personagem.
	var aro := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.7
	aro.mesh = tm
	var c: Color = st.cor_time
	var mat_aro := StandardMaterial3D.new()
	mat_aro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_aro.albedo_color = c
	mat_aro.emission_enabled = true
	mat_aro.emission = c
	mat_aro.emission_energy_multiplier = 1.6
	aro.material_override = mat_aro
	raiz.add_child(aro)
	aro.position.y = -1.0
	# Luzes de estúdio.
	var key := OmniLight3D.new()
	key.light_energy = 2.4
	key.omni_range = 10.0
	raiz.add_child(key)
	key.position = Vector3(-1.5, 1.6, 2.2)
	var fill := OmniLight3D.new()
	fill.light_energy = 1.0
	fill.light_color = c.lerp(Color.WHITE, 0.4)
	fill.omni_range = 10.0
	raiz.add_child(fill)
	fill.position = Vector3(1.8, 0.4, 1.4)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 32.0
	cam.position = Vector3(0.0, 0.35, 3.6)
	cam.look_at(Vector3(0.0, 0.05, 0.0), Vector3.UP)
	cam.current = true
	# Giro lento contínuo do personagem (vitrine de loja).
	var tw := raiz.create_tween().set_loops()
	tw.tween_property(m, "rotation:y", TAU, 14.0).from(0.0)


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
