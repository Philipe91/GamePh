extends Control
## Tela de seleção de personagem (GDD 4 / Fase 5, C3).
##
## Mostra os 6 do roster; ao escolher, guarda no GameManager e vai pra arena. O bot
## pega o próximo da lista. Em modo de teste/demo (qualquer arg `--…`), pula direto pra
## arena pra não travar a suíte headless.

const ROSTER: Array[String] = ["brecht", "magnus", "vesna", "pip", "kestrel", "mara"]
const ARENA := "res://scenes/arena/arena.tscn"
## Mapas disponíveis (nome + caminho do .tres).
const MAPAS: Array = [
	{"nome": "Padrão", "path": "res://resources/mapas/padrao.tres"},
	{"nome": "Corredor", "path": "res://resources/mapas/corredor.tres"},
	{"nome": "Fortaleza", "path": "res://resources/mapas/fortaleza.tres"},
	{"nome": "Cruz Vertical", "path": "res://resources/mapas/vertical.tres"},
]

const UIEstilo := preload("res://scenes/ui/ui_estilo.gd")

var _mapa_path: String = "res://resources/mapas/padrao.tres"
var _mapa_label: Label = null


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
	UIEstilo.fundo_neon(self)

	# CenterContainer ocupa a tela e centraliza a coluna de botões.
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "VAULTBREAKER"
	titulo.add_theme_font_size_override("font_size", 36)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIEstilo.titulo_glow(titulo)
	caixa.add_child(titulo)

	# Linha de seleção de mapa.
	_mapa_label = Label.new()
	_mapa_label.text = "Mapa: Padrão"
	_mapa_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	_mapa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(_mapa_label)

	var linha_mapas := HBoxContainer.new()
	linha_mapas.alignment = BoxContainer.ALIGNMENT_CENTER
	linha_mapas.add_theme_constant_override("separation", 8)
	caixa.add_child(linha_mapas)
	for m in MAPAS:
		var mb := Button.new()
		mb.text = m["nome"]
		mb.custom_minimum_size = Vector2(150, 38)
		UIEstilo.estilizar_botao(mb, Color(0.5, 0.8, 1.0))
		mb.pressed.connect(_escolher_mapa.bind(String(m["path"]), String(m["nome"])))
		linha_mapas.add_child(mb)

	var sub := Label.new()
	sub.text = "escolha o personagem para começar"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(sub)

	for nome in ROSTER:
		var st: Resource = load("res://resources/personagens/%s.tres" % nome)
		var b := Button.new()
		b.custom_minimum_size = Vector2(440, 46)
		b.text = "%s   —   vida %d · vel %.1f · %s" % [st.nome, int(st.vida_max), st.velocidade, st.arma]
		UIEstilo.estilizar_botao(b, st.cor_time)   # cada um na sua cor
		b.pressed.connect(_escolher.bind(nome))
		caixa.add_child(b)


func _escolher_mapa(path: String, nome: String) -> void:
	_mapa_path = path
	_mapa_label.text = "Mapa: " + nome


func _escolher(nome: String) -> void:
	GameManager.personagem_jogador = "res://resources/personagens/%s.tres" % nome
	var i := ROSTER.find(nome)
	GameManager.personagem_bot = "res://resources/personagens/%s.tres" % ROSTER[(i + 1) % ROSTER.size()]
	GameManager.mapa = _mapa_path
	_ir_pra_arena()


func _ir_pra_arena() -> void:
	# Deferido: chamar do _ready troca a cena com a árvore ocupada (warning de remove_child).
	get_tree().change_scene_to_file.call_deferred(ARENA)
