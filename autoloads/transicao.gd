extends CanvasLayer
## Transição de cena com FADE (polimento Steam): escurece, troca a cena, clareia.
## Uso: `Transicao.ir_para("res://scenes/ui/selecao.tscn")` no lugar de
## change_scene_to_file. Em headless (testes/demos) troca DIRETO, sem fade — a
## suíte não espera tweens de UI.

var _veu: ColorRect = null
var _ocupado: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veu = ColorRect.new()
	_veu.color = Color(0.0, 0.0, 0.0, 0.0)
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veu)


func ir_para(caminho: String) -> void:
	if _ocupado:
		return
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().is_empty():
		# Testes/demos: sem cerimônia (timing determinístico).
		get_tree().change_scene_to_file.call_deferred(caminho)
		return
	_ocupado = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_veu, "color:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	await tw.finished
	get_tree().change_scene_to_file(caminho)
	var tw2 := create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_property(_veu, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	_ocupado = false
