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
var _oponente: Node = null
var _fim: bool = false   # partida acabou: habilita o rematch (Enter)
var _ultimo_restante: float = 0.0   # p/ mostrar a duração na tela de fim
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
	# Código de desarme em fonte MONO (dígitos/setas alinhados — leitura de terminal).
	if ResourceLoader.exists("res://assets/fonts/JetBrainsMono.ttf"):
		lbl_desarme.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono.ttf"))
	# Timer em Orbitron (display de placar).
	if ResourceLoader.exists("res://assets/fonts/Orbitron.ttf"):
		lbl_timer.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
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
	_oponente = p2
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
	_mostrar_dica_controles()
	_montar_objetivo()


## Objetivo especial do Story visível no topo (abaixo do placar), com progresso.
func _montar_objetivo() -> void:
	if GameManager.objetivo == "":
		return
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_left = -220.0
	lbl.offset_right = 220.0
	lbl.offset_top = 88.0
	lbl.offset_bottom = 112.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	match GameManager.objetivo:
		"desarmes":
			lbl.text = "OBJETIVO: desarme %d armadilhas (0/%d)" % [GameManager.objetivo_meta, GameManager.objetivo_meta]
			GameManager.objetivo_progrediu.connect(func(atual: int, meta: int) -> void:
				lbl.text = "OBJETIVO: desarme %d armadilhas (%d/%d)" % [meta, atual, meta])
		"sobreviver":
			lbl.text = "OBJETIVO: sobreviva até o tempo acabar"
	add_child(lbl)


## Lembrete de controles no rodapé durante os primeiros segundos (fade e some).
func _mostrar_dica_controles() -> void:
	var dica := Label.new()
	dica.text = "WASD mover · ESPAÇO plantar · TAB roda · C desarmar · J atirar · K soco · F detonar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_font_size_override("font_size", 13)
	dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	dica.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dica.offset_top = -30.0
	dica.offset_bottom = -8.0
	add_child(dica)
	var tw := dica.create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(dica, "modulate:a", 0.0, 1.5)
	tw.tween_callback(dica.queue_free)


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


var _pips_municao: Array = []   # ColorRects dos "cartuchos" (HUD visual, não texto)


## Munição como PIPS (barrinhas que apagam ao gastar) — HUD comercial, não printf.
func _ao_municao_mudar(atual: int, maximo: int) -> void:
	if _pips_municao.size() != maximo:
		_montar_pips_municao(maximo)
	if _jogador != null and _jogador.esta_recarregando():
		lbl_municao.text = "RECARREGANDO…"
		lbl_municao.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		for p in _pips_municao:
			(p as ColorRect).color = Color(1.0, 0.5, 0.3, 0.25)
		return
	lbl_municao.text = "MUNIÇÃO"
	lbl_municao.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	for i in _pips_municao.size():
		var cheio := i < atual
		(_pips_municao[i] as ColorRect).color = \
			Color(1.0, 0.85, 0.3, 1.0) if cheio else Color(1.0, 1.0, 1.0, 0.12)


func _montar_pips_municao(maximo: int) -> void:
	var antigo := get_node_or_null("PipsMunicao")
	if antigo != null:
		antigo.queue_free()
	_pips_municao.clear()
	lbl_municao.add_theme_font_size_override("font_size", 14)
	var linha := HBoxContainer.new()
	linha.name = "PipsMunicao"
	linha.add_theme_constant_override("separation", 4)
	linha.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	linha.offset_left = lbl_municao.offset_left + 130.0
	linha.offset_top = lbl_municao.offset_top + 4.0
	linha.offset_right = linha.offset_left + 160.0
	linha.offset_bottom = linha.offset_top + 16.0
	add_child(linha)
	for i in maximo:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9.0, 16.0)
		linha.add_child(pip)
		_pips_municao.append(pip)


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
		Transicao.ir_para("res://scenes/ui/selecao.tscn")
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
	_ultimo_restante = restante
	lbl_timer.text = "%d" % ceili(restante)
	# Urgência: nos 10 segundos finais o timer fica vermelho e pulsa (leitura imediata).
	if restante <= 10.0:
		var pulso := 0.65 + 0.35 * absf(sin(restante * PI))
		lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.35 * pulso + 0.1, 0.2))
	elif restante <= 30.0:
		lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))  # aviso Spark Bit
	else:
		lbl_timer.remove_theme_color_override("font_color")


## TELA DE FIM memorável (missão Steam): véu escurecendo, painel com borda na cor do
## resultado, retrato do vencedor, placar, duração e botões — com animação de entrada.
func _ao_partida_acabar(vencedor_id: int, motivo: String) -> void:
	_fim = true
	var cor := Color(1.0, 0.9, 0.4)            # empate = amarelo
	var titulo := "EMPATE"
	if vencedor_id == 1:
		cor = Color(0.3, 1.0, 0.5)
		titulo = "VITÓRIA"
	elif vencedor_id == 2:
		cor = Color(1.0, 0.4, 0.45)
		titulo = "DERROTA"
	# Véu que escurece a arena (foco total no resultado).
	var veu := ColorRect.new()
	veu.color = Color(0.0, 0.0, 0.02, 0.0)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veu)
	veu.create_tween().tween_property(veu, "color:a", 0.72, 0.5)
	# Painel central.
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.94)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(30.0)
	sb.set_border_width_all(2)
	sb.border_color = Color(cor.r, cor.g, cor.b, 0.7)
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.35)
	sb.shadow_size = 22
	painel.add_theme_stylebox_override("panel", sb)
	centro.add_child(painel)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	painel.add_child(caixa)
	var lbl_titulo := Label.new()
	lbl_titulo.text = titulo
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_font_size_override("font_size", 52)
	lbl_titulo.add_theme_color_override("font_color", Color.WHITE)
	lbl_titulo.add_theme_color_override("font_shadow_color", Color(cor.r, cor.g, cor.b, 0.95))
	lbl_titulo.add_theme_constant_override("shadow_offset_x", 0)
	lbl_titulo.add_theme_constant_override("shadow_offset_y", 0)
	lbl_titulo.add_theme_constant_override("shadow_outline_size", 18)
	caixa.add_child(lbl_titulo)
	# Retrato do vencedor (se houver personagem com retrato).
	var vencedor: Node = _jogador if vencedor_id == 1 else _oponente
	if vencedor_id != 0 and vencedor != null and is_instance_valid(vencedor):
		var stats: Resource = vencedor.get("stats")
		if stats != null:
			var caminho := "res://assets/sprites/retratos/%s.png" % String(stats.nome).to_lower()
			if ResourceLoader.exists(caminho):
				var tr := TextureRect.new()
				tr.texture = load(caminho)
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.custom_minimum_size = Vector2(128.0, 128.0)
				var moldura := PanelContainer.new()
				var msb := StyleBoxFlat.new()
				msb.bg_color = Color(0, 0, 0, 0)
				msb.set_border_width_all(2)
				msb.border_color = cor
				msb.set_corner_radius_all(10)
				moldura.add_theme_stylebox_override("panel", msb)
				moldura.add_child(tr)
				var linha_r := HBoxContainer.new()
				linha_r.alignment = BoxContainer.ALIGNMENT_CENTER
				linha_r.add_child(moldura)
				caixa.add_child(linha_r)
				var lbl_nome := Label.new()
				lbl_nome.text = String(stats.nome)
				lbl_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl_nome.add_theme_font_size_override("font_size", 22)
				lbl_nome.add_theme_color_override("font_color", cor)
				caixa.add_child(lbl_nome)
	# Estatísticas da partida: motivo, placar de rounds e duração do round final.
	var lbl_stats := Label.new()
	var placar := _lbl_placar.text if _lbl_placar != null else ""
	var dur := maxf(0.0, GameManager.DURACAO_PARTIDA - _ultimo_restante)
	lbl_stats.text = "%s\nrounds  %s   ·   round final  %ds" % [motivo, placar, int(dur)]
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_stats.add_theme_font_size_override("font_size", 16)
	lbl_stats.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	caixa.add_child(lbl_stats)
	# Botões.
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 12)
	caixa.add_child(linha)
	var UIEstilo := preload("res://scenes/ui/ui_estilo.gd")
	var rematch := Button.new()
	rematch.text = "Jogar de novo  (Enter)"
	rematch.custom_minimum_size = Vector2(230, 44)
	UIEstilo.estilizar_botao(rematch, cor)
	rematch.pressed.connect(func(): Transicao.ir_para("res://scenes/ui/selecao.tscn"))
	linha.add_child(rematch)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(120, 44)
	UIEstilo.estilizar_botao(menu, Color(0.6, 0.6, 0.7))
	menu.pressed.connect(func(): Transicao.ir_para("res://scenes/ui/titulo.tscn"))
	linha.add_child(menu)
	# Entrada com "pop" (escala 0.85 -> 1.0 com easing) — momento memorável.
	painel.pivot_offset = painel.size * 0.5
	painel.scale = Vector2(0.85, 0.85)
	painel.modulate.a = 0.0
	var tw := painel.create_tween().set_parallel()
	tw.tween_property(painel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(painel, "modulate:a", 1.0, 0.25)
