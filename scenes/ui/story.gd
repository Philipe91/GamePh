extends Control
## Story Mode — ESQUELETO navegável (GDD 15 Fase 7). Lista de missões placeholder; cada
## uma escolhe mapa/dificuldade e leva pra seleção de personagem → arena. Campanha de
## verdade (objetivos, chefe da VECTOR, missões de desarme) entra numa fase futura.

const TITULO := "res://scenes/ui/titulo.tscn"
const SELECAO := "res://scenes/ui/selecao.tscn"
const UIEstilo := preload("res://scenes/ui/ui_estilo.gd")

const MISSOES: Array = [
	{"nome": "Missão 1 — Treinamento", "mapa": "padrao", "dif": "facil"},
	{"nome": "Missão 2 — Fábrica VECTOR", "mapa": "corredor", "dif": "normal"},
	{"nome": "Missão 3 — O Cofre (chefe)", "mapa": "fortaleza", "dif": "dificil"},
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

	for m in MISSOES:
		var b := Button.new()
		b.text = String(m["nome"])
		b.custom_minimum_size = Vector2(420, 46)
		UIEstilo.estilizar_botao(b)
		b.pressed.connect(_missao.bind(String(m["mapa"]), String(m["dif"])))
		caixa.add_child(b)

	var voltar := Button.new()
	voltar.text = "Voltar"
	voltar.custom_minimum_size = Vector2(200, 40)
	UIEstilo.estilizar_botao(voltar, Color(0.6, 0.6, 0.7))
	voltar.pressed.connect(_voltar)
	caixa.add_child(voltar)


func _missao(mapa: String, dif: String) -> void:
	GameManager.modo = "vs_com"
	GameManager.mapa = "res://resources/mapas/%s.tres" % mapa
	GameManager.dificuldade = dif
	get_tree().change_scene_to_file.call_deferred(SELECAO)


func _voltar() -> void:
	get_tree().change_scene_to_file.call_deferred(TITULO)


func _capturar() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_captura_arena.png")
	get_tree().quit()
