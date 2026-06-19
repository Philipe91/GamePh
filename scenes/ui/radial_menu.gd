extends Control
## Menu radial de seleção das 6 armadilhas (GDD 6.4).
##
## Só DESENHA: lê o estado do player (radial aberto, fatia atual, cores e contagens) e
## pinta a roda. A lógica de abrir/escolher/confirmar fica no player (_ler_radial).

const RAIO_RODA: float = 150.0   # distância das fatias ao centro
const RAIO_FATIA: float = 26.0   # tamanho da bolha de cada armadilha
const RAIO_SELE: float = 36.0    # tamanho da bolha selecionada

const PASTA_ICONES := "res://assets/sprites/armadilhas/"

var _jogador: Node = null
var _icones: Dictionary = {}   # tipo -> Texture2D (ou null se não houver arquivo)
var _t: float = 0.0            # tempo acumulado (pulso/animação do neon)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Carrega o ícone PNG do tipo, se existir em assets/sprites/armadilhas/<tipo>.png.
## Usa Image.load (lê o arquivo do disco direto, sem depender de import do editor).
func _icone(tipo: String) -> Texture2D:
	if _icones.has(tipo):
		return _icones[tipo]
	var tex: Texture2D = null
	var caminho := PASTA_ICONES + tipo + ".png"
	if FileAccess.file_exists(caminho):
		var img := Image.new()
		if img.load(caminho) == OK:
			tex = ImageTexture.create_from_image(img)
	_icones[tipo] = tex
	return tex


## A HUD chama isto passando o player (mesmo padrão de hud.configurar).
func configurar(jogador: Node) -> void:
	_jogador = jogador
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()  # roda barata; redesenha enquanto a cena vive


## Halo neon (bloom fake) com camadas concêntricas decaindo o alfa.
func _halo(p: Vector2, cor: Color, raio_base: float, intensidade: float) -> void:
	for c in range(5):
		var r := raio_base + float(c) * 5.0
		draw_circle(p, r, Color(cor.r, cor.g, cor.b, intensidade * (1.0 - float(c) / 5.0)))


func _draw() -> void:
	if _jogador == null or not _jogador.radial_aberto():
		return
	var centro := size / 2.0
	var ordem: Array = _jogador.ORDEM
	var idx: int = _jogador.radial_idx()
	var fonte := get_theme_default_font()
	var passo := TAU / float(ordem.size())
	var pulso := 0.5 + 0.5 * sin(_t * 5.0)   # 0..1 pulsante (anima o neon da seleção)

	# Fundo: disco escuro com vinheta + leve tom ciano + anel neon conectando as fatias.
	draw_circle(centro, RAIO_RODA + 95.0, Color(0.02, 0.03, 0.06, 0.78))
	draw_circle(centro, RAIO_RODA + 95.0, Color(0.0, 0.85, 1.0, 0.04))
	draw_arc(centro, RAIO_RODA, 0.0, TAU, 80, Color(0.3, 0.7, 1.0, 0.18), 2.0, true)

	for i in ordem.size():
		var ang := -PI / 2.0 + float(i) * passo   # índice 0 no topo, sentido horário
		var p := centro + Vector2(cos(ang), sin(ang)) * RAIO_RODA
		var tipo: String = ordem[i]
		var cor: Color = _jogador.STATS[tipo].cor
		var nome: String = _jogador.STATS[tipo].nome
		var qtd: int = int(_jogador.inventario.get(tipo, 0))
		var sel := i == idx
		var raio := RAIO_SELE if sel else RAIO_FATIA
		var vivo := qtd > 0

		# Linha neon do centro até a fatia selecionada.
		if sel:
			draw_line(centro, p, Color(cor.r, cor.g, cor.b, 0.35), 2.0, true)

		# Halo / bloom atrás (mais forte e pulsante na selecionada).
		var inten := (0.16 + 0.12 * pulso) if sel else 0.05
		if vivo:
			_halo(p, cor, raio + 2.0, inten)
		# "Pod" base escuro pra o ícone descansar.
		draw_circle(p, raio + 3.0, Color(0.05, 0.06, 0.10, 0.9))

		# Ícone (ou bolha colorida fallback). Selecionado fica maior.
		var icone := _icone(tipo)
		if icone != null:
			var lado := raio * (2.9 if sel else 2.5)
			draw_texture_rect(icone, Rect2(p - Vector2(lado, lado) * 0.5, Vector2(lado, lado)),
				false, Color(1, 1, 1, 1.0 if vivo else 0.3))
		else:
			draw_circle(p, raio, Color(cor.r, cor.g, cor.b, 0.9 if vivo else 0.3))

		# Anel neon da fatia. Selecionado: duplo anel pulsante (branco + cor).
		if sel:
			draw_arc(p, raio + 6.0 + 3.0 * pulso, 0.0, TAU, 48, Color(1, 1, 1, 0.95), 3.0, true)
			draw_arc(p, raio + 11.0 + 3.0 * pulso, 0.0, TAU, 48, Color(cor.r, cor.g, cor.b, 0.5), 5.0, true)
		else:
			draw_arc(p, raio + 4.0, 0.0, TAU, 40, Color(cor.r, cor.g, cor.b, 0.45), 2.0, true)

		# Rótulos: nome (branco/apagado) + contagem na cor do tipo.
		var cor_nome := Color(1, 1, 1) if vivo else Color(0.55, 0.55, 0.6)
		draw_string(fonte, p + Vector2(-70.0, raio + 22.0), nome,
			HORIZONTAL_ALIGNMENT_CENTER, 140.0, 20 if sel else 18, cor_nome)
		draw_string(fonte, p + Vector2(-70.0, raio + 42.0), "x%d" % qtd,
			HORIZONTAL_ALIGNMENT_CENTER, 140.0, 18, cor)

	# Miolo: hub escuro com aro neon + nome grande da fatia atual, na cor dela.
	var atual: String = ordem[idx]
	var cor_atual: Color = _jogador.STATS[atual].cor
	var nome_atual: String = _jogador.STATS[atual].nome
	_halo(centro, cor_atual, 22.0, 0.10 + 0.08 * pulso)
	draw_circle(centro, 26.0, Color(0.05, 0.06, 0.10, 0.95))
	draw_arc(centro, 30.0, 0.0, TAU, 48, Color(cor_atual.r, cor_atual.g, cor_atual.b, 0.6), 2.0, true)
	draw_string(fonte, centro + Vector2(-120.0, 6.0), nome_atual,
		HORIZONTAL_ALIGNMENT_CENTER, 240.0, 30, cor_atual)
