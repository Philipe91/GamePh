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


## Dá um glow (sombra borrada sem deslocamento) num Label de título.
static func titulo_glow(lbl: Label, cor: Color = Color(0.3, 0.7, 1.0)) -> void:
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(cor.r, cor.g, cor.b, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 16)


## Fundo escuro full-rect com uma linha de acento neon no topo. Retorna o ColorRect base.
static func fundo_neon(pai: Control, cor: Color = Color(0.3, 0.7, 1.0)) -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.04, 0.08)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(fundo)
	var acento := ColorRect.new()
	acento.color = Color(cor.r, cor.g, cor.b, 0.5)
	acento.set_anchors_preset(Control.PRESET_TOP_WIDE)
	acento.offset_bottom = 3.0
	acento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(acento)
