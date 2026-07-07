extends Control
## Story Mode — ESQUELETO navegável (GDD 15 Fase 7). Lista de missões placeholder; cada
## uma escolhe mapa/dificuldade e leva pra seleção de personagem → arena. Campanha de
## verdade (objetivos, chefe da VECTOR, missões de desarme) entra numa fase futura.

const TITULO := "res://scenes/ui/titulo.tscn"
const SELECAO := "res://scenes/ui/selecao.tscn"
const UIEstilo := preload("res://scenes/ui/ui_estilo.gd")

## Campanha VECTOR: 5 missões com objetivos variados (GDD 12 — nem toda missão é
## "mate o oponente"). Vencer uma missão desbloqueia a próxima (persistido).
const MISSOES: Array = [
	{"nome": "1 — Treinamento", "mapa": "padrao", "dif": "facil",
		"obj": "", "meta": 0, "desc": "Vença a partida"},
	{"nome": "2 — Porto de Carga", "mapa": "porto", "dif": "normal",
		"obj": "desarmes", "meta": 3, "desc": "Desarme 3 armadilhas inimigas"},
	{"nome": "3 — Fábrica VECTOR", "mapa": "corredor", "dif": "normal",
		"obj": "", "meta": 0, "desc": "Vença a partida"},
	{"nome": "4 — O Cerco", "mapa": "fortaleza", "dif": "dificil",
		"obj": "sobreviver", "meta": 0, "desc": "Sobreviva até o tempo acabar"},
	{"nome": "5 — Setor 07 (chefe)", "mapa": "setor07", "dif": "dificil",
		"obj": "", "meta": 0, "desc": "Derrote o executor da VECTOR"},
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo-story" in args:
		_montar_ui()
		_capturar()
		return
	if not args.is_empty():
		_voltar()
		return
	_montar_ui()


func _montar_ui() -> void:
	UIEstilo.fundo_neon(self)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "STORY — Campanha VECTOR"
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIEstilo.titulo_glow(titulo)
	caixa.add_child(titulo)

	var progresso := int(Persistencia.get_config("story", "missao", 0))
	for i in MISSOES.size():
		var m: Dictionary = MISSOES[i]
		var b := Button.new()
		b.text = "%s   ·   %s" % [String(m["nome"]), String(m["desc"])]
		b.custom_minimum_size = Vector2(520, 46)
		var liberada := i <= progresso
		UIEstilo.estilizar_botao(b, Color(0.5, 0.8, 1.0) if liberada else Color(0.35, 0.35, 0.4))
		b.disabled = not liberada
		if not liberada:
			b.text = "🔒  " + b.text
		b.pressed.connect(_missao.bind(i))
		caixa.add_child(b)

	var voltar := Button.new()
	voltar.text = "Voltar"
	voltar.custom_minimum_size = Vector2(200, 40)
	UIEstilo.estilizar_botao(voltar, Color(0.6, 0.6, 0.7))
	voltar.pressed.connect(_voltar)
	caixa.add_child(voltar)


func _missao(idx: int) -> void:
	var m: Dictionary = MISSOES[idx]
	GameManager.modo = "vs_com"
	GameManager.mapa = "res://resources/mapas/%s.tres" % String(m["mapa"])
	GameManager.dificuldade = String(m["dif"])
	GameManager.objetivo = String(m["obj"])
	GameManager.objetivo_meta = int(m["meta"])
	GameManager.story_missao = idx
	get_tree().change_scene_to_file.call_deferred(SELECAO)


func _voltar() -> void:
	Transicao.ir_para(TITULO)


func _capturar() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_captura_arena.png")
	get_tree().quit()
