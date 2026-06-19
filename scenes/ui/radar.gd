extends Control
## Radar / minimapa (GDD 11). Desenha pontos do mundo num quadradinho, com as cores do
## GDD: azul = jogador 1, vermelho = jogador 2, verde = Vault, amarelo = field trap /
## armadilha detectada, azul claro = ponte/passarela.

const COR_FUNDO := Color(0.0, 0.0, 0.0, 0.45)
const COR_BORDA := Color(0.3, 0.5, 0.7, 0.7)


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


## Converte uma posição de mundo (XZ, arena centrada na origem) pro espaço do radar.
func mundo_para_radar(p: Vector3, tamanho: Vector2) -> Vector2:
	var larg := float(GridManager.LARGURA) * GridManager.TAMANHO_TILE
	var alt := float(GridManager.ALTURA) * GridManager.TAMANHO_TILE
	var u := (p.x + larg * 0.5) / larg
	var v := (p.z + alt * 0.5) / alt
	return Vector2(clampf(u, 0.0, 1.0) * tamanho.x, clampf(v, 0.0, 1.0) * tamanho.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)
	draw_rect(Rect2(Vector2.ZERO, size), COR_BORDA, false, 2.0)
	# Vaults (verde), pontes (azul claro), field traps (amarelo) e combatentes (azul/vermelho).
	_pontos("vaults", Color(0.2, 1.0, 0.4), 3.0)
	_pontos("pontes", Color(0.5, 0.8, 1.0), 3.0)
	_pontos("destrutiveis", Color(1.0, 0.85, 0.1), 2.5)
	for c in get_tree().get_nodes_in_group("combatentes"):
		if not is_instance_valid(c):
			continue
		var cor := Color(0.3, 0.7, 1.0) if int(c.get("id_jogador")) == 1 else Color(1.0, 0.35, 0.4)
		draw_circle(mundo_para_radar(c.global_position, size), 4.0, cor)


func _pontos(grupo: String, cor: Color, raio: float) -> void:
	for n in get_tree().get_nodes_in_group(grupo):
		if is_instance_valid(n):
			draw_circle(mundo_para_radar(n.global_position, size), raio, cor)
