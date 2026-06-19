extends Control
## Menu radial de seleção das 6 armadilhas (GDD 6.4).
##
## Só DESENHA: lê o estado do player (radial aberto, fatia atual, cores e contagens) e
## pinta a roda. A lógica de abrir/escolher/confirmar fica no player (_ler_radial).

const RAIO_RODA: float = 150.0   # distância das fatias ao centro
const RAIO_FATIA: float = 26.0   # tamanho da bolha de cada armadilha
const RAIO_SELE: float = 36.0    # tamanho da bolha selecionada

var _jogador: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## A HUD chama isto passando o player (mesmo padrão de hud.configurar).
func configurar(jogador: Node) -> void:
	_jogador = jogador
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()  # roda barata; redesenha enquanto a cena vive


func _draw() -> void:
	if _jogador == null or not _jogador.radial_aberto():
		return
	var centro := size / 2.0
	var ordem: Array = _jogador.ORDEM
	var idx: int = _jogador.radial_idx()
	var fonte := get_theme_default_font()
	var passo := TAU / float(ordem.size())

	# Fundo escurecido pra destacar a roda.
	draw_circle(centro, RAIO_RODA + 70.0, Color(0.0, 0.0, 0.0, 0.55))

	for i in ordem.size():
		var ang := -PI / 2.0 + float(i) * passo   # índice 0 no topo, sentido horário
		var p := centro + Vector2(cos(ang), sin(ang)) * RAIO_RODA
		var tipo: String = ordem[i]
		var cor: Color = _jogador.STATS[tipo].cor
		var nome: String = _jogador.STATS[tipo].nome
		var qtd: int = int(_jogador.inventario.get(tipo, 0))
		var sel := i == idx
		var raio := RAIO_SELE if sel else RAIO_FATIA
		# Armadilha sem estoque fica apagada.
		var alfa := (0.95 if sel else 0.55) * (1.0 if qtd > 0 else 0.3)
		draw_circle(p, raio, Color(cor.r, cor.g, cor.b, alfa))
		if sel:
			draw_arc(p, raio + 5.0, 0.0, TAU, 40, Color(1, 1, 1, 0.95), 3.0)
		draw_string(fonte, p + Vector2(-60.0, raio + 18.0), nome,
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, Color.WHITE)
		draw_string(fonte, p + Vector2(-60.0, raio + 38.0), "x%d" % qtd,
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, cor)

	# Nome grande da fatia atual no miolo.
	var atual: String = ordem[idx]
	draw_string(fonte, centro + Vector2(-90.0, 8.0), _jogador.STATS[atual].nome,
		HORIZONTAL_ALIGNMENT_CENTER, 180.0, 26, Color.WHITE)
