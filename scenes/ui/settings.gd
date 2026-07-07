extends Control
## Tela de configurações (GDD 15 Fase 7). Volume master, persistido via Persistencia.
## Acessível pelo título; "Voltar" retorna. Em modo de teste/demo, não trava.

const TITULO := "res://scenes/ui/titulo.tscn"
const UIEstilo := preload("res://scenes/ui/ui_estilo.gd")

var _vol_label: Label = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo-settings" in args:
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
	caixa.add_theme_constant_override("separation", 16)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "CONFIGURAÇÕES"
	titulo.add_theme_font_size_override("font_size", 32)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIEstilo.titulo_glow(titulo)
	caixa.add_child(titulo)

	_vol_label = Label.new()
	_vol_label.text = "Volume: %d%%" % int(AudioManager.volume * 100.0)
	_vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(_vol_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = AudioManager.volume * 100.0
	slider.custom_minimum_size = Vector2(360.0, 24.0)
	slider.value_changed.connect(_ao_volume)
	caixa.add_child(slider)

	var voltar := Button.new()
	voltar.text = "Voltar"
	voltar.custom_minimum_size = Vector2(200.0, 44.0)
	UIEstilo.estilizar_botao(voltar)
	voltar.pressed.connect(_voltar)
	caixa.add_child(voltar)


func _ao_volume(v: float) -> void:
	AudioManager.aplicar_volume(v / 100.0)
	_vol_label.text = "Volume: %d%%" % int(v)
	Persistencia.set_config("audio", "volume", v / 100.0)
	Persistencia.salvar()


func _voltar() -> void:
	Transicao.ir_para(TITULO)


func _capturar() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_captura_arena.png")
	get_tree().quit()
