extends Node3D
## Arena — mapa do vertical slice.
##
## A ESTRUTURA visual (câmera ortográfica top-down, luz, chão, ambiente e o player)
## está GRAVADA na cena arena.tscn — então aparece direto no editor, sem rodar.
## Aqui no script fica só o que é dinâmico: desenhar as linhas do grid lógico
## (puxando as dimensões do GridManager, fonte de verdade do grid — GDD seção 5) e
## reagir ao fim de partida.

@onready var player: CharacterBody3D = $Player
@onready var bot: CharacterBody3D = $Bot


func _ready() -> void:
	_desenhar_grid()
	player.healer_zerou.connect(_ao_player_morrer)
	bot.healer_zerou.connect(_ao_bot_morrer)
	print("[Arena] pronta — grid %dx%d, tile %.1fu" % [GridManager.LARGURA, GridManager.ALTURA, GridManager.TAMANHO_TILE])
	var args := OS.get_cmdline_user_args()
	# Teste automatizado do loop (planta mina, bot pisa, leva dano). Só com --teste.
	if "--teste" in args:
		_rodar_teste()
		return
	# Demo visual: planta uma de cada armadilha e captura (mostra cores/tamanhos).
	if "--demo" in args:
		_demo_armadilhas_e_capturar()
		return
	# Modo captura automatizada (screenshot pro dev). Só roda se passado --capturar.
	if "--capturar" in args:
		_capturar_e_sair()
		return
	# Modo normal de jogo: liga a HUD e inicia a partida (timer + regras de vitória).
	$HUD.configurar(player, bot)
	GameManager.iniciar_partida([player, bot])


## Por ora só registra; as regras completas de vitória vêm no bloco 5 (HUD/GameManager).
func _ao_player_morrer() -> void:
	print("[Arena] Healer do jogador zerou — fim de partida (placeholder).")


func _ao_bot_morrer() -> void:
	print("[Arena] Healer do bot zerou — jogador venceu (placeholder).")


## Desenha as linhas do grid como ImmediateMesh, em neon ciano discreto. Roda ao jogar.
func _desenhar_grid() -> void:
	var linhas := MeshInstance3D.new()
	linhas.name = "LinhasGrid"
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.85, 1.0, 0.45)

	var lg := GridManager.LARGURA
	var al := GridManager.ALTURA
	var ts := GridManager.TAMANHO_TILE
	var meio_x := float(lg) * ts * 0.5
	var meio_z := float(al) * ts * 0.5
	var y := 0.02  # levemente acima do chão pra não dar z-fighting

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	# Linhas paralelas ao eixo Z (divisórias entre colunas)
	for i in range(lg + 1):
		var x := float(i) * ts - meio_x
		im.surface_add_vertex(Vector3(x, y, -meio_z))
		im.surface_add_vertex(Vector3(x, y, meio_z))
	# Linhas paralelas ao eixo X (divisórias entre linhas)
	for j in range(al + 1):
		var z := float(j) * ts - meio_z
		im.surface_add_vertex(Vector3(-meio_x, y, z))
		im.surface_add_vertex(Vector3(meio_x, y, z))
	im.surface_end()

	linhas.mesh = im
	add_child(linhas)


## Teste automatizado do loop do bloco 3/4 (roda headless com --teste e encerra).
## Verifica: plantio com snap, ocupação do tile, inventário, bloqueio de tile duplo,
## e a explosão quando o bot pisa (dano + liberação do tile).
func _rodar_teste() -> void:
	# Desliga a perseguição do bot pra controlar a posição dele no teste.
	bot.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var falhas := 0

	var coord := GridManager.world_to_grid(player.global_position)
	falhas += _checar("plantar() retorna true", player.plantar("mina"))
	falhas += _checar("tile fica ocupado", GridManager.tem_armadilha(coord))
	falhas += _checar("inventario mina cai pra 3", int(player.inventario["mina"]) == 3)
	falhas += _checar("nao planta 2x no mesmo tile", not player.plantar("mina"))

	# Tira o player de cima da mina pra ela ficar livre pro bot pisar.
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 1.0, 10.0)
	await get_tree().create_timer(0.6).timeout  # espera a mina armar (0,5s)

	# Bot ANDA até a mina (caminho real do gameplay), partindo 3u ao sul do tile.
	var centro := GridManager.grid_to_world(coord)
	var vida_bot_antes: float = bot.healer
	bot.global_position = Vector3(centro.x, 1.0, centro.z - 3.0)
	for _i in range(120):
		if bot.healer < vida_bot_antes:
			break
		var para := centro - bot.global_position
		para.y = 0.0
		if para.length() < 0.1:
			break
		var d := para.normalized()
		bot.velocity = Vector3(d.x * 5.0, 0.0, d.z * 5.0)
		bot.move_and_slide()
		bot.position.y = 1.0
		await get_tree().physics_frame
	falhas += _checar("bot tomou dano ao pisar", bot.healer < vida_bot_antes)
	falhas += _checar("tile liberado apos explodir", not GridManager.tem_armadilha(coord))

	# Fase 3 bloco 1: combo Bomba + Detonador.
	# Planta uma bomba e um detonador em tiles vizinhos; o detonador aciona a bomba.
	var coord_b := Vector2i(2, 2)
	var coord_d := Vector2i(3, 2)
	player.global_position = GridManager.grid_to_world(coord_b)
	falhas += _checar("planta bomba", player.plantar("bomba"))
	player.global_position = GridManager.grid_to_world(coord_d)
	falhas += _checar("planta detonador", player.plantar("detonador"))
	await get_tree().create_timer(0.6).timeout  # arma bomba (0,4s) e detonador (0,3s)
	# Bot no tile da bomba pra confirmar o dano em área do combo.
	bot.global_position = GridManager.grid_to_world(coord_b)
	var vida_bot_combo: float = bot.healer
	player.acionar_detonadores()
	await get_tree().physics_frame
	await get_tree().physics_frame
	falhas += _checar("combo: bomba explode pelo detonador", not GridManager.tem_armadilha(coord_b))
	falhas += _checar("combo: bot toma dano em area", bot.healer < vida_bot_combo)

	# Fase 3 bloco 2: Cova (imobiliza), Painel (arremessa), Gás (dano + slow).
	falhas += _checar("cova/painel/gas no inventario", player.inventario.has("cova") and player.inventario.has("painel") and player.inventario.has("gas"))

	# Cova: bot ANDA até o tile e fica imobilizado.
	var coord_cova := Vector2i(6, 6)
	player.global_position = GridManager.grid_to_world(coord_cova)
	player.plantar("cova")
	await get_tree().create_timer(0.4).timeout
	await _andar_bot_para(GridManager.grid_to_world(coord_cova))
	falhas += _checar("cova imobiliza o bot", bot.esta_imobilizado())

	# Painel: bot anda até o tile e é arremessado (salto de posição num frame só).
	var coord_pn := Vector2i(8, 8)
	player.global_position = GridManager.grid_to_world(coord_pn)
	player.plantar("painel")
	await get_tree().create_timer(0.4).timeout
	var centro_pn := GridManager.grid_to_world(coord_pn)
	bot.global_position = Vector3(centro_pn.x, 1.0, centro_pn.z - 3.0)
	var arremessado := false
	var prev := bot.global_position
	for _i in range(120):
		var para := centro_pn - bot.global_position
		para.y = 0.0
		var d := para.normalized()
		bot.velocity = Vector3(d.x * 5.0, 0.0, d.z * 5.0)
		bot.move_and_slide()
		bot.position.y = 1.0
		await get_tree().physics_frame
		if bot.global_position.distance_to(prev) > 2.0:
			arremessado = true  # salto grande = arremesso do painel
			break
		prev = bot.global_position
		if para.length() < 0.2:
			break
	falhas += _checar("painel arremessa o bot", arremessado)

	# Gás: emite após o tempo e causa dano + slow em quem está na nuvem (pulso de área).
	var coord_gas := Vector2i(5, 9)
	player.global_position = GridManager.grid_to_world(coord_gas)
	player.plantar("gas")
	bot.global_position = GridManager.grid_to_world(coord_gas)
	var vida_bot_gas: float = bot.healer
	await get_tree().create_timer(2.2).timeout  # arma 0,4s + emite 1,5s (folga)
	await get_tree().physics_frame
	falhas += _checar("gas causa dano na nuvem", bot.healer < vida_bot_gas)
	falhas += _checar("gas aplica slow", bot.fator_velocidade() < 1.0)

	# Bloco 5: regras de vitória.
	GameManager.iniciar_partida([player, bot])
	falhas += _checar("partida inicia em 90s", is_equal_approx(GameManager.tempo_restante, 90.0))
	var venceu := { "id": -1 }
	GameManager.partida_acabou.connect(func(vid: int, _m: String): venceu["id"] = vid)
	bot.receber_dano(999.0)  # zera o Healer do bot -> jogador vence
	await get_tree().physics_frame
	falhas += _checar("jogador vence quando bot zera", venceu["id"] == 1)

	if falhas == 0:
		print("[TESTE] RESULTADO: TODOS OS TESTES PASSARAM")
	else:
		print("[TESTE] RESULTADO: %d FALHA(S)" % falhas)
	get_tree().quit()


func _checar(nome: String, condicao: bool) -> int:
	print("[TESTE] %s -> %s" % [nome, "OK" if condicao else "FALHOU"])
	return 0 if condicao else 1


## Faz o bot caminhar (via move_and_slide) de 3u ao sul até `centro`, parando ao chegar.
## Usado nos testes pra disparar gatilhos de "pisar" de forma realista (teleporte não dispara).
func _andar_bot_para(centro: Vector3, max_frames: int = 120) -> void:
	bot.global_position = Vector3(centro.x, 1.0, centro.z - 3.0)
	for _i in range(max_frames):
		var para := centro - bot.global_position
		para.y = 0.0
		if para.length() < 1.2:
			break
		var d := para.normalized()
		bot.velocity = Vector3(d.x * 5.0, 0.0, d.z * 5.0)
		bot.move_and_slide()
		bot.position.y = 1.0
		await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


## Planta uma de cada armadilha numa fileira e captura (dev: ver cores/tamanhos).
func _demo_armadilhas_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	bot.global_position = Vector3(9, 1, -9)  # tira o bot da frente
	var tipos := ["mina", "bomba", "detonador", "gas", "cova", "painel"]
	await get_tree().physics_frame
	for i in tipos.size():
		player.global_position = GridManager.grid_to_world(Vector2i(2 + i, 6))
		player.plantar(tipos[i])
	player.global_position = Vector3(-9, 1, 9)  # tira o player da frente
	_capturar_e_sair()


## Espera a cena renderizar, salva um PNG do viewport e encerra. Uso só de dev.
func _capturar_e_sair() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var caminho := "res://_captura_arena.png"
	img.save_png(caminho)
	print("[Arena] captura salva em ", ProjectSettings.globalize_path(caminho))
	get_tree().quit()
