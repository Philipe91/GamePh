extends Control
## Tela de seleção de personagem (GDD 4 / Fase 5, C3).
##
## Mostra os 6 do roster; ao escolher, guarda no GameManager e vai pra arena. O bot
## pega o próximo da lista. Em modo de teste/demo (qualquer arg `--…`), pula direto pra
## arena pra não travar a suíte headless.

const ROSTER: Array[String] = ["brecht", "magnus", "vesna", "pip", "kestrel", "mara"]
const ARENA := "res://scenes/arena/arena.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo-selecao" in args:
		_montar_ui()
		_capturar()       # screenshot da tela e sai
		return
	if not args.is_empty():
		_ir_pra_arena()   # --teste / --demo* / --capturar: nada de UI
		return
	_montar_ui()


## Captura a tela (dev) e encerra. Não trava: render + quit.
func _capturar() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_captura_arena.png")
	get_tree().quit()


func _montar_ui() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.06, 0.1)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	# CenterContainer ocupa a tela e centraliza a coluna de botões.
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "VAULTBREAKER — escolha seu personagem"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(titulo)

	for nome in ROSTER:
		var st: Resource = load("res://resources/personagens/%s.tres" % nome)
		var b := Button.new()
		b.custom_minimum_size = Vector2(420, 44)
		b.text = "%s   —   vida %d · vel %.1f · %s" % [st.nome, int(st.vida_max), st.velocidade, st.arma]
		b.pressed.connect(_escolher.bind(nome))
		caixa.add_child(b)


func _escolher(nome: String) -> void:
	GameManager.personagem_jogador = "res://resources/personagens/%s.tres" % nome
	var i := ROSTER.find(nome)
	GameManager.personagem_bot = "res://resources/personagens/%s.tres" % ROSTER[(i + 1) % ROSTER.size()]
	_ir_pra_arena()


func _ir_pra_arena() -> void:
	get_tree().change_scene_to_file(ARENA)
