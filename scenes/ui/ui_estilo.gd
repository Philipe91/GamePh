extends RefCounted
## Estilo neon compartilhado das telas (Fase 7 — polimento). Funções estáticas pra
## aplicar botões com hover glow e títulos com brilho. Usar via preload const.

## Aplica visual neon num botão: fundo escuro, borda na cor, e GLOW no hover/foco.
static func estilizar_botao(b: Button, cor: Color = Color(0.3, 0.7, 1.0)) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.1, 0.16, 0.92)
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(1)
	normal.border_color = Color(cor.r, cor.g, cor.b, 0.45)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.16, 0.24, 0.95)
	hover.set_border_width_all(2)
	hover.border_color = cor
	hover.shadow_color = Color(cor.r, cor.g, cor.b, 0.55)
	hover.shadow_size = 10

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(cor.r, cor.g, cor.b, 0.3)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	# Feedback SONORO (tick no hover/foco, confirmação no clique) — UI comercial fala.
	b.mouse_entered.connect(func(): AudioManager.tocar("ui_click"))
	b.focus_entered.connect(func(): AudioManager.tocar("ui_click"))
	b.pressed.connect(func(): AudioManager.tocar("ui_confirm"))


## Dá um glow (sombra borrada sem deslocamento) num Label de título.
## Títulos usam ORBITRON (display); o corpo do jogo usa Rajdhani (global, legível).
static func titulo_glow(lbl: Label, cor: Color = Color(0.3, 0.7, 1.0)) -> void:
	if ResourceLoader.exists("res://assets/fonts/Orbitron.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/Orbitron.ttf"))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(cor.r, cor.g, cor.b, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 16)


## Fundo com PROFUNDIDADE: gradiente vertical escuro, poeira de partículas subindo,
## vinheta radial e linhas de acento neon (topo/rodapé). Menu vivo, não retângulo.
static func fundo_neon(pai: Control, cor: Color = Color(0.3, 0.7, 1.0)) -> void:
	# Gradiente vertical (mais claro no alto — luz vindo "da cidade").
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.06, 0.08, 0.14), Color(0.015, 0.02, 0.045)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var fundo := TextureRect.new()
	fundo.texture = gtex
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(fundo)
	# Poeira/fagulhas flutuando (vida). Pré-processada: a tela já abre povoada.
	var p := CPUParticles2D.new()
	p.amount = 36
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1000.0, 400.0)
	p.position = Vector2(576.0, 500.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 34.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	p.color = Color(cor.r, cor.g, cor.b, 0.16)
	pai.add_child(p)
	# Vinheta radial (foco no centro — acabamento de menu comercial).
	var vin_grad := Gradient.new()
	vin_grad.colors = PackedColorArray([Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.42)])
	var vin_tex := GradientTexture2D.new()
	vin_tex.gradient = vin_grad
	vin_tex.fill = GradientTexture2D.FILL_RADIAL
	vin_tex.fill_from = Vector2(0.5, 0.5)
	vin_tex.fill_to = Vector2(0.5, 0.0)
	var vinheta := TextureRect.new()
	vinheta.texture = vin_tex
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(vinheta)
	# Linhas de acento neon no topo e rodapé.
	for topo in [true, false]:
		var acento := ColorRect.new()
		acento.color = Color(cor.r, cor.g, cor.b, 0.5 if topo else 0.25)
		acento.set_anchors_preset(Control.PRESET_TOP_WIDE if topo else Control.PRESET_BOTTOM_WIDE)
		if topo:
			acento.offset_bottom = 3.0
		else:
			acento.offset_top = -2.0
		acento.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pai.add_child(acento)
