extends CanvasLayer
## HUD do vertical slice (bloco 5): dois Healers, timer e contador de minas.
##
## Só OUVE (por signal); não puxa estado ativamente. A arena chama configurar()
## passando os dois combatentes, e o timer/fim vêm do GameManager.

@onready var barra_p1: ProgressBar = $P1Bar
@onready var barra_p2: ProgressBar = $P2Bar
@onready var lbl_timer: Label = $TimerLabel
@onready var lbl_minas: Label = $MinasLabel
@onready var lbl_municao: Label = $MunicaoLabel
@onready var lbl_unit: Label = $UnitLabel
@onready var lbl_fim: Label = $FimLabel
@onready var lbl_desarme: Label = $DesarmeLabel
@onready var lbl_retomada: Label = $RetomadaLabel

## Setas pra desenhar o Disarming Code (índice = código de direção 0..3).
const SETAS: Array[String] = ["↑", "↓", "←", "→"]

var _jogador: Node = null
var _fim: bool = false   # partida acabou: habilita o rematch (Enter)
var _lbl_placar: Label = null    # placar de rounds (ex.: "1  -  0")
var _lbl_round: Label = null      # anúncio grande "ROUND N"
var _t_round_aviso: float = 0.0   # tempo restante do anúncio na tela
var _arma_icone: TextureRect = null   # ícone da armadilha selecionada (canto inferior esq.)
var _icones_arma: Dictionary = {}     # tipo -> Texture2D (cache)


## Carrega o PNG do ícone da armadilha (mesmo da roda). Prefere a textura IMPORTADA
## (load pega o .ctex — funciona no export, onde o PNG cru não existe no PCK);
## Image.load fica só como fallback de dev pra PNG largado na pasta sem import.
func _icone_arma(tipo: String) -> Texture2D:
	if _icones_arma.has(tipo):
		return _icones_arma[tipo]
	var tex: Texture2D = null
	var caminho := "res://assets/sprites/armadilhas/%s.png" % tipo
	if ResourceLoader.exists(caminho):
		tex = load(caminho) as Texture2D
	elif FileAccess.file_exists(caminho):
		var img := Image.new()
		if img.load(caminho) == OK:
			tex = ImageTexture.create_from_image(img)
	_icones_arma[tipo] = tex
	return tex


## Aplica um visual neon (StyleBoxFlat com glow) numa ProgressBar de Healer.
func _estilizar_barra(barra: ProgressBar, cor: Color) -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.08, 0.09, 0.13)
	fundo.set_corner_radius_all(6)
	fundo.set_border_width_all(1)
	fundo.border_color = Color(cor.r, cor.g, cor.b, 0.4)
	var preenche := StyleBoxFlat.new()
	preenche.bg_color = cor
	preenche.set_corner_radius_all(6)
	preenche.shadow_color = Color(cor.r, cor.g, cor.b, 0.6)  # glow
	preenche.shadow_size = 8
	barra.add_theme_stylebox_override("background", fundo)
	barra.add_theme_stylebox_override("fill", preenche)
	barra.modulate = Color.WHITE


func _ready() -> void:
	lbl_fim.visible = false
	GameManager.tempo_mudou.connect(_ao_tempo_mudar)
	GameManager.partida_acabou.connect(_ao_partida_acabar)
	# Timer grande num painel escuro (leitura central, estilo arcade do original).
	lbl_timer.add_theme_font_size_override("font_size", 38)
	var painel := StyleBoxFlat.new()
	painel.bg_color = Color(0.02, 0.03, 0.06, 0.75)
	painel.set_corner_radius_all(10)
	painel.set_content_margin_all(6.0)
	painel.set_border_width_all(1)
	painel.border_color = Color(0.4, 0.6, 0.9, 0.5)
	lbl_timer.add_theme_stylebox_override("normal", painel)


## Liga as barras aos Healers e o contador à armadilha selecionada do jogador.
func configurar(p1: Node, p2: Node) -> void:
	_jogador = p1
	p1.healer_mudou.connect(_ao_healer_mudar.bind(barra_p1))
	p2.healer_mudou.connect(_ao_healer_mudar.bind(barra_p2))
	p1.inventario_mudou.connect(_ao_inventario_mudar)
	p1.selecao_mudou.connect(_ao_selecao_mudar)
	p1.municao_mudou.connect(_ao_municao_mudar)
	barra_p1.max_value = p1.vida_max
	barra_p1.value = p1.healer
	barra_p2.max_value = p2.vida_max
	barra_p2.value = p2.healer
	_ao_municao_mudar(p1.municao, p1.municao_max)
	$RadialMenu.configurar(p1)  # a roda lê o estado do jogador
	# Barras de Healer com neon (cor de time).
	_estilizar_barra(barra_p1, Color(0.3, 0.7, 1.0))
	_estilizar_barra(barra_p2, Color(1.0, 0.35, 0.4))
	# Retratos dos personagens ao lado das barras (arte oficial do pack — Trap Gunner
	# mostrava os lutadores no topo). Falha silenciosa se o personagem não tiver retrato.
	_montar_retrato(p1, Control.PRESET_TOP_LEFT, Vector2(10.0, 58.0))
	_montar_retrato(p2, Control.PRESET_TOP_RIGHT, Vector2(-74.0, 58.0))
	# Ícone da armadilha selecionada no canto inferior esquerdo.
	_arma_icone = TextureRect.new()
	_arma_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arma_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arma_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arma_icone.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_arma_icone.offset_left = 14.0
	_arma_icone.offset_top = -52.0
	_arma_icone.offset_right = 52.0
	_arma_icone.offset_bottom = -12.0
	add_child(_arma_icone)
	lbl_minas.offset_left = 58.0   # abre espaço pro ícone na mesma linha
	# Placar de rounds (topo-centro, abaixo do timer) e anúncio "ROUND N".
	_lbl_placar = Label.new()
	_lbl_placar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_placar.offset_left = -80.0
	_lbl_placar.offset_right = 80.0
	_lbl_placar.offset_top = 58.0
	_lbl_placar.offset_bottom = 86.0
	_lbl_placar.add_theme_font_size_override("font_size", 22)
	_lbl_placar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_placar.text = "0  -  0"
	add_child(_lbl_placar)
	_lbl_round = Label.new()
	_lbl_round.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_round.offset_left = -200.0
	_lbl_round.offset_right = 200.0
	_lbl_round.offset_top = -120.0
	_lbl_round.offset_bottom = -60.0
	_lbl_round.add_theme_font_size_override("font_size", 48)
	_lbl_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_round.visible = false
	add_child(_lbl_round)
	GameManager.placar_mudou.connect(func(a: int, b: int): _lbl_placar.text = "%d  -  %d" % [a, b])
	GameManager.round_comecou.connect(_ao_round_comecou)
	_atualizar_label_armadilha()


## Retrato do personagem (assets/sprites/retratos/<nome>.png, nome do stats em
## minúsculas). Sem stats ou sem arquivo, não mostra nada.
func _montar_retrato(c: Node, preset: int, deslocamento: Vector2) -> void:
	var stats: Resource = c.get("stats")
	if stats == null:
		return
	var caminho := "res://assets/sprites/retratos/%s.png" % String(stats.nome).to_lower()
	if not ResourceLoader.exists(caminho):
		return
	var tr := TextureRect.new()
	tr.texture = load(caminho)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_preset(preset)
	tr.offset_left = deslocamento.x
	tr.offset_top = deslocamento.y
	tr.offset_right = deslocamento.x + 64.0
	tr.offset_bottom = deslocamento.y + 64.0
	add_child(tr)


## Healer com FEEDBACK (juice): a barra desce/sobe animada (não salta) e pisca —
## clarão frio no dano, verde na cura. O tween novo mata o anterior (sem briga).
func _ao_healer_mudar(atual: float, maximo: float, barra: ProgressBar) -> void:
	barra.max_value = maximo
	if atual < barra.value:
		barra.modulate = Color(1.8, 1.8, 2.0)      # levou dano: flash
	elif atual > barra.value:
		barra.modulate = Color(0.8, 1.6, 1.0)      # curou: pulso verde
	var tw := barra.create_tween()
	tw.tween_property(barra, "value", atual, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(barra, "modulate", Color.WHITE, 0.3)


func _ao_round_comecou(numero: int) -> void:
	_lbl_round.text = "ROUND %d" % numero
	_lbl_round.visible = true
	_t_round_aviso = 1.5


## Mostra "Nome: quantidade" da armadilha selecionada (rodapé esquerdo).
func _atualizar_label_armadilha() -> void:
	if _jogador == null:
		return
	var sel: String = _jogador.selecao
	var qtd: int = int(_jogador.inventario.get(sel, 0))
	var nome: String = _jogador.STATS[sel].nome
	lbl_minas.text = "%s: %d" % [nome, qtd]
	if _arma_icone != null:
		_arma_icone.texture = _icone_arma(sel)
		_arma_icone.modulate = Color.WHITE if qtd > 0 else Color(1, 1, 1, 0.4)


func _ao_inventario_mudar(tipo: String, _atual: int, _maximo: int) -> void:
	if _jogador != null and tipo == _jogador.selecao:
		_atualizar_label_armadilha()


func _ao_selecao_mudar(_tipo: String) -> void:
	_atualizar_label_armadilha()


func _ao_municao_mudar(atual: int, maximo: int) -> void:
	if _jogador != null and _jogador.esta_recarregando():
		lbl_municao.text = "Munição: recarregando…"
	else:
		lbl_municao.text = "Munição: %d/%d" % [atual, maximo]


## Painel de desarme e prompt de retomada são dinâmicos (timer correndo): leio o estado
## do jogador a cada frame em vez de mil signals por segundo.
func _process(_delta: float) -> void:
	# Some o anúncio "ROUND N" depois de um tempo.
	if _t_round_aviso > 0.0:
		_t_round_aviso -= _delta
		if _t_round_aviso <= 0.0 and _lbl_round != null:
			_lbl_round.visible = false
	# Rematch: ao fim da partida, Enter volta pra seleção de personagem.
	if _fim and Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/selecao.tscn")
		return
	if _jogador == null:
		return
	if _jogador.desarme_ativo():
		var e: Dictionary = _jogador.desarme_estado()
		var seq: Array = e["seq"]
		var idx: int = e["idx"]
		var codigo := ""
		for i in seq.size():
			var s: String = SETAS[int(seq[i])]
			codigo += ("[%s] " % s) if i < idx else ("%s " % s)  # acertados entre colchetes
		lbl_desarme.text = "DESARMAR  %s\n%.1fs" % [codigo.strip_edges(), maxf(0.0, e["tempo"])]
		lbl_desarme.visible = true
	else:
		lbl_desarme.visible = false
	lbl_retomada.visible = _jogador.retomada_disponivel()
	# Unit/Plasma: mostra carga ou estoque quando o jogador tem a Unit.
	if _jogador.tem_unit:
		lbl_unit.visible = true
		if _jogador.esta_carregando_unit():
			lbl_unit.text = "UNIT: carregando %d%%" % int(_jogador.carga_unit_frac() * 100.0)
		else:
			lbl_unit.text = "UNIT x%d (segure U)" % _jogador.plasma_bombs
	else:
		lbl_unit.visible = false


func _ao_tempo_mudar(restante: float) -> void:
	lbl_timer.text = "%d" % ceili(restante)
	# Urgência: nos 10 segundos finais o timer fica vermelho e pulsa (leitura imediata).
	if restante <= 10.0:
		var pulso := 0.65 + 0.35 * absf(sin(restante * PI))
		lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.35 * pulso + 0.1, 0.2))
	elif restante <= 30.0:
		lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))  # aviso Spark Bit
	else:
		lbl_timer.remove_theme_color_override("font_color")


func _ao_partida_acabar(vencedor_id: int, motivo: String) -> void:
	if vencedor_id == 0:
		lbl_fim.text = "EMPATE\n(%s)" % motivo
	elif vencedor_id == 1:
		lbl_fim.text = "VOCÊ VENCEU\n(%s)" % motivo
	else:
		lbl_fim.text = "VOCÊ PERDEU\n(%s)" % motivo
	lbl_fim.text += "\n\nEnter: jogar de novo"
	# Estilo premium: cor por resultado, texto com glow e painel escuro com borda neon.
	var cor := Color(1.0, 0.9, 0.4)            # empate = amarelo
	if vencedor_id == 1:
		cor = Color(0.3, 1.0, 0.5)             # vitória = verde
	elif vencedor_id == 2:
		cor = Color(1.0, 0.4, 0.45)            # derrota = vermelho
	lbl_fim.add_theme_color_override("font_color", cor)
	lbl_fim.add_theme_color_override("font_shadow_color", Color(cor.r, cor.g, cor.b, 0.9))
	lbl_fim.add_theme_constant_override("shadow_offset_x", 0)
	lbl_fim.add_theme_constant_override("shadow_offset_y", 0)
	lbl_fim.add_theme_constant_override("shadow_outline_size", 18)
	var painel := StyleBoxFlat.new()
	painel.bg_color = Color(0.02, 0.03, 0.06, 0.88)
	painel.set_corner_radius_all(14)
	painel.set_content_margin_all(28.0)
	painel.set_border_width_all(2)
	painel.border_color = Color(cor.r, cor.g, cor.b, 0.6)
	painel.shadow_color = Color(cor.r, cor.g, cor.b, 0.35)
	painel.shadow_size = 16
	lbl_fim.add_theme_stylebox_override("normal", painel)
	lbl_fim.visible = true
	_fim = true
