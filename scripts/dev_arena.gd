extends Node
## DevArena — suíte de testes headless e demos de captura, EXTRAÍDAS de arena.gd.
##
## arena.gd tinha 1489 linhas, das quais ~1100 eram testes/demos misturados ao código
## de produção (god-file). Este módulo concentra tudo que é de desenvolvimento: a arena
## o instancia no _ready e chama executar(); se algum modo dev assumir, a arena não
## monta a partida normal. Nenhum comportamento foi alterado na extração.
##
## Rodar a suíte:  godot --headless --path <projeto> ++ --teste
## Rodar uma demo: godot --path <projeto> ++ --demo-<nome>   (salva _captura_arena.png)

var arena: Node3D

## Atalhos: os testes falam "player"/"bot" o tempo todo (legibilidade do corpo do teste).
var player: CharacterBody3D:
	get:
		return arena.player
var bot: CharacterBody3D:
	get:
		return arena.bot


## Despacha o modo dev pedido nos args. Retorna true se assumiu o controle da cena
## (a arena então NÃO inicia a partida normal). false = nenhum modo dev pedido.
func executar(a: Node3D, args: PackedStringArray) -> bool:
	arena = a
	if "--teste" in args:
		_rodar_teste()
		return true
	if "--demo" in args:
		_demo_armadilhas_e_capturar()
		return true
	if "--demo-caution" in args:
		_demo_caution_e_capturar()
		return true
	if "--demo-desarme" in args:
		_demo_desarme_e_capturar()
		return true
	if "--demo-radial" in args:
		_demo_radial_e_capturar()
		return true
	if "--demo-combate" in args:
		_demo_combate_e_capturar()
		return true
	if "--demo-mapa" in args:
		_demo_mapa_e_capturar()
		return true
	if "--demo-modelo" in args:
		_demo_modelo_e_capturar()
		return true
	if "--demo-greybox" in args:
		_demo_greybox_e_capturar()
		return true
	if "--demo-setor07" in args:
		_demo_setor07_e_capturar()
		return true
	if "--demo-vertical" in args:
		_demo_vertical_e_capturar()
		return true
	if "--demo-padrao" in args:
		_demo_mapa_povoado_e_capturar("res://resources/mapas/padrao.tres")
		return true
	if "--demo-porto" in args:
		_demo_mapa_povoado_e_capturar("res://resources/mapas/porto.tres")
		return true
	if "--demo-fim" in args:
		_demo_fim_e_capturar()
		return true
	if "--retratos" in args:
		_gerar_retratos()
		return true
	if "--capturar" in args:
		_capturar_e_sair()
		return true
	return false


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


## Teste automatizado de TODO o loop (roda headless com --teste e encerra).
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
	var coord_b := Vector2i(2, 2)
	var coord_d := Vector2i(3, 2)
	player.global_position = GridManager.grid_to_world(coord_b)
	falhas += _checar("planta bomba", player.plantar("bomba"))
	player.global_position = GridManager.grid_to_world(coord_d)
	falhas += _checar("planta detonador", player.plantar("detonador"))
	await get_tree().create_timer(0.6).timeout  # arma bomba (0,4s) e detonador (0,3s)
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

	# Painel: bot anda até o tile e é arremessado (impulso forte de knockback).
	var coord_pn := Vector2i(8, 8)
	player.global_position = GridManager.grid_to_world(coord_pn)
	player.plantar("painel")
	await get_tree().create_timer(0.4).timeout
	var centro_pn := GridManager.grid_to_world(coord_pn)
	bot.global_position = Vector3(centro_pn.x, 1.0, centro_pn.z - 3.0)
	var arremessado := false
	for _i in range(120):
		var para := centro_pn - bot.global_position
		para.y = 0.0
		var d := para.normalized()
		bot.velocity = Vector3(d.x * 5.0, 0.0, d.z * 5.0) + bot.velocidade_impulso()
		bot.move_and_slide()
		bot.position.y = 1.0
		await get_tree().physics_frame
		if bot.velocidade_impulso().length() > 1.0:
			arremessado = true  # painel disparou: bot ganhou impulso de arremesso
		if arremessado and bot.velocidade_impulso().length() < 0.5:
			break               # impulso já decaiu: encerra o passeio
		if para.length() < 0.2 and not arremessado:
			break
	falhas += _checar("painel arremessa o bot", arremessado)
	falhas += _checar("arremesso desloca de verdade", bot.global_position.distance_to(centro_pn) > 2.0)

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

	# Fase 3 bloco 3: Caution Mode (detecção da teia inimiga).
	var coord_inim := Vector2i(1, 1)
	bot.global_position = GridManager.grid_to_world(coord_inim)
	bot._tentar_plantar_mina()
	falhas += _checar("bot planta mina (dono 2)", GridManager.armadilha_em(coord_inim).get("dono") == 2)
	player.global_position = GridManager.grid_to_world(Vector2i(2, 1))  # 1 tile de distância
	player.ativar_caution(true)
	falhas += _checar("caution detecta mina inimiga no alcance", coord_inim in player.armadilhas_detectadas())
	player.plantar("mina")
	var coord_propria := GridManager.world_to_grid(player.global_position)
	falhas += _checar("caution ignora a propria armadilha", not (coord_propria in player.armadilhas_detectadas()))
	# Invisibilidade REAL (GDD 6): cada armadilha renderiza só na camada do dono —
	# a câmera do adversário corta essa camada (cull_mask).
	var no_inim: Node = GridManager.armadilha_em(coord_inim).get("no")
	var no_prop: Node = GridManager.armadilha_em(coord_propria).get("no")
	falhas += _checar("armadilha do bot na camada oculta (12)", no_inim.marca.layers == (1 << 11))
	falhas += _checar("armadilha do player na camada propria (11)", no_prop.marca.layers == (1 << 10))
	player.global_position = GridManager.grid_to_world(Vector2i(10, 10))
	falhas += _checar("caution nao detecta fora do alcance", player.armadilhas_detectadas().is_empty())
	player.ativar_caution(false)
	falhas += _checar("caution off nao detecta nada", player.armadilhas_detectadas().is_empty())

	# Fase 3 bloco 4: Desarme (6.2) e retomada (6.3).
	player.ativar_caution(true)
	# (a) Sucesso: bot planta mina; player encosta em Caution -> desarme; código certo.
	player._desarme_cooldown = 0.0
	var coord_des := Vector2i(3, 3)
	bot.global_position = GridManager.grid_to_world(coord_des)
	bot._tentar_plantar_mina()
	player.global_position = GridManager.grid_to_world(coord_des)
	player.receber_dano(30.0)            # garante folga pra enxergar a cura
	var vida_pre: float = player.healer
	player._ler_interacao()              # encosta -> inicia desarme (automático)
	falhas += _checar("desarme inicia ao encostar em caution", player.desarme_ativo())
	for d in player._desarme_seq.duplicate():
		player.inserir_botao(d)          # digita o código correto
	falhas += _checar("desarme: sucesso remove a armadilha inimiga", not GridManager.tem_armadilha(coord_des))
	falhas += _checar("desarme: sucesso cura o jogador", player.healer > vida_pre)
	falhas += _checar("desarme: encerra apos sucesso", not player.desarme_ativo())

	# (b) Código errado: mina (explosiva) detona.
	player._desarme_cooldown = 0.0
	var coord_err := Vector2i(4, 4)
	bot.global_position = GridManager.grid_to_world(coord_err)
	bot._tentar_plantar_mina()
	player.global_position = GridManager.grid_to_world(coord_err)
	player._ler_interacao()
	var certo: int = player._desarme_seq[0]
	player.inserir_botao((certo + 1) % 4)   # botão errado
	falhas += _checar("desarme: codigo errado encerra", not player.desarme_ativo())
	falhas += _checar("desarme: codigo errado detona a mina", not GridManager.tem_armadilha(coord_err))

	# (c) Tempo esgotado encerra o desarme.
	player._desarme_cooldown = 0.0
	var coord_t := Vector2i(5, 4)
	bot.global_position = GridManager.grid_to_world(coord_t)
	bot._tentar_plantar_mina()
	player.global_position = GridManager.grid_to_world(coord_t)
	player._ler_interacao()
	player._desarme_tempo = 0.05
	player._processar_desarme(0.2)          # delta passa do tempo -> falha
	falhas += _checar("desarme: tempo esgotado encerra", not player.desarme_ativo())

	# (d) Tomar golpe durante o desarme detona na hora.
	player._desarme_cooldown = 0.0
	var coord_h := Vector2i(6, 4)
	bot.global_position = GridManager.grid_to_world(coord_h)
	bot._tentar_plantar_mina()
	player.global_position = GridManager.grid_to_world(coord_h)
	player._ler_interacao()
	falhas += _checar("desarme (d) inicia", player.desarme_ativo())
	player.receber_dano(5.0)                # golpe no meio do desarme
	falhas += _checar("desarme: golpe encerra na hora", not player.desarme_ativo())

	# (e) Retomada da própria armadilha (GDD 6.3).
	player._desarme_cooldown = 0.0
	var coord_ret := Vector2i(7, 4)
	player.global_position = GridManager.grid_to_world(coord_ret)
	player.plantar("cova")                  # planta uma cova própria
	var inv_antes: int = int(player.inventario["cova"])
	player.global_position = GridManager.grid_to_world(coord_ret)
	player._ler_interacao()                 # encosta na própria -> retomada disponível
	falhas += _checar("retomada disponivel na propria armadilha", player.retomada_disponivel())
	player._retomar(player._retomada_alvo)
	falhas += _checar("retomar libera o tile", not GridManager.tem_armadilha(coord_ret))
	falhas += _checar("retomar devolve +1 ao inventario", int(player.inventario["cova"]) == inv_antes + 1)
	player.ativar_caution(false)

	# Fase 3 (UX): menu radial de seleção das 6 armadilhas.
	falhas += _checar("radial: cima -> idx 0 (mina)", player._dir_para_idx(Vector2(0, -1)) == 0)
	falhas += _checar("radial: baixo -> idx 3 (gas)", player._dir_para_idx(Vector2(0, 1)) == 3)
	player.selecionar_idx(2)
	falhas += _checar("radial: selecionar_idx troca a selecao", player.selecao == player.ORDEM[2])
	player.selecionar_idx(0)  # volta pra mina

	# Bloco A (Fase 3): faro/desvio de armadilhas do player pela IA do bot.
	bot.set_physics_process(false)
	var coord_mina_a := Vector2i(9, 9)
	player.inventario["mina"] = 4
	player.global_position = GridManager.grid_to_world(coord_mina_a)
	player.plantar("mina")                                  # mina do player (dono 1)
	var pos_mina_a := GridManager.grid_to_world(coord_mina_a)
	bot.global_position = pos_mina_a + Vector3(0.0, 0.0, -1.5)  # bot dentro do raio de faro
	var desvio_a: Vector3 = bot._desvio_de_armadilhas()
	falhas += _checar("bot sente a armadilha do player", desvio_a.length() > 0.0)
	falhas += _checar("bot desvia pra LONGE da armadilha", (bot.global_position - pos_mina_a).dot(desvio_a) > 0.0)
	bot.global_position = GridManager.grid_to_world(Vector2i(0, 0))  # longe de tudo
	falhas += _checar("sem armadilha perto, bot nao desvia", bot._desvio_de_armadilhas().length() < 0.001)

	# IA do bot: recua (kite) quando com pouca vida.
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 1.0, 0.0)
	bot.gravidade_ativa = false
	bot.healer = 10.0                          # pouca vida -> foge
	bot._imobilizado_restante = 0.0            # limpa resíduo de Cova/Gás dos testes
	bot._slow_restante = 0.0
	bot._derrubado_restante = 0.0
	bot.global_position = Vector3(0.0, 1.0, -3.0)
	bot._alvo = player
	bot.set_physics_process(true)              # liga a IA
	var dist_fuga: float = bot.global_position.distance_to(player.global_position)
	for _i in range(40):
		await get_tree().physics_frame
	falhas += _checar("bot recua com pouca vida", bot.global_position.distance_to(player.global_position) > dist_fuga + 1.0)
	bot.set_physics_process(false)
	bot.healer = Combatente.HEALER_MAX
	# IA do bot: planta Cova quando o player está perto (prende quem persegue).
	var coord_cv := Vector2i(1, 4)
	GridManager.remover_armadilha(coord_cv)
	bot.global_position = GridManager.grid_to_world(coord_cv)
	bot._armadilhas_ativas = 0
	bot._plantar_situacional(3.0)              # dist < 6 -> cova
	falhas += _checar("bot planta Cova com o player perto", GridManager.armadilha_em(coord_cv).get("tipo") == "cova")
	GridManager.remover_armadilha(coord_cv)
	# IA do bot (território): perto de uma Vault e com o player longe, planta MINA
	# (nega o ponto de interesse), mesmo na faixa de distância que normalmente daria cova.
	var vault_ia: Node = arena._colocar_vault(Vector2i(3, 6))
	await get_tree().physics_frame
	var coord_vz := Vector2i(3, 7)              # tile vizinho da Vault
	GridManager.remover_armadilha(coord_vz)
	bot.global_position = GridManager.grid_to_world(coord_vz)
	bot._armadilhas_ativas = 0
	bot._plantar_situacional(5.0)               # perto de Vault -> mina o território
	falhas += _checar("bot mina o territorio da Vault", GridManager.armadilha_em(coord_vz).get("tipo") == "mina")
	GridManager.remover_armadilha(coord_vz)
	vault_ia.queue_free()
	await get_tree().physics_frame

	# G2: dificuldade do bot ajusta a IA (params setados no _ready; physics off pra não agir).
	GameManager.dificuldade = "dificil"
	var bot_dif := preload("res://scenes/characters/bot.tscn").instantiate()
	bot_dif.position = Vector3(60.0, 1.0, 60.0)
	arena.add_child(bot_dif)
	bot_dif.set_physics_process(false)
	falhas += _checar("dificil: mais armadilhas e mira melhor", bot_dif._max_armadilhas == 6 and bot_dif._limiar_tiro < 0.6)
	bot_dif.queue_free()
	GameManager.dificuldade = "facil"
	var bot_facil := preload("res://scenes/characters/bot.tscn").instantiate()
	bot_facil.position = Vector3(60.0, 1.0, -60.0)
	arena.add_child(bot_facil)
	bot_facil.set_physics_process(false)
	falhas += _checar("facil: nao kita e poucas armadilhas", (not bot_facil._kite) and bot_facil._max_armadilhas <= 2)
	bot_facil.queue_free()
	GameManager.dificuldade = "normal"

	# G4: o bot desarma uma armadilha do player ao encostar (fica parado e exposto).
	for p in get_tree().get_nodes_in_group("projeteis"):
		p.queue_free()
	for a in get_tree().get_nodes_in_group("armadilhas"):
		a.queue_free()
	GridManager.configurar_mapa(preload("res://scripts/stats_mapa.gd").new())  # grid 12x12 limpo
	await get_tree().physics_frame
	var coord_dz := Vector2i(4, 7)
	player.set_physics_process(false)
	player.inventario["mina"] = 4
	player.global_position = GridManager.grid_to_world(coord_dz)
	player.plantar("mina")                       # mina do player
	player.global_position = Vector3(25.0, 1.0, 0.0)   # tira o player de cena
	bot._imobilizado_restante = 0.0
	bot._slow_restante = 0.0
	bot._derrubado_restante = 0.0
	bot._desarmando = null
	bot.healer = Combatente.HEALER_MAX
	bot.gravidade_ativa = false
	bot.global_position = GridManager.grid_to_world(coord_dz) + Vector3(0.0, 0.0, 1.0)  # ~1u da mina
	bot._alvo = player
	bot.set_physics_process(true)
	for _i in range(140):                        # desarme leva 1.5s (~90 frames) + folga
		await get_tree().physics_frame
	falhas += _checar("bot desarma a armadilha do player", not GridManager.tem_armadilha(coord_dz))
	bot.set_physics_process(false)

	# G6: bot busca o Healer da Vault quando está com pouca vida.
	for p in get_tree().get_nodes_in_group("projeteis"):
		p.queue_free()
	for a in get_tree().get_nodes_in_group("armadilhas"):
		a.queue_free()
	GridManager.configurar_mapa(preload("res://scripts/stats_mapa.gd").new())
	await get_tree().physics_frame
	player.global_position = Vector3(30.0, 1.0, 0.0)   # player bem longe
	var heal := preload("res://scenes/items/item.tscn").instantiate()
	heal.tipo = "healer"
	arena.add_child(heal)
	heal.global_position = Vector3(0.0, 1.0, 8.0)       # item ao norte
	bot._imobilizado_restante = 0.0
	bot._slow_restante = 0.0
	bot._derrubado_restante = 0.0
	bot._desarmando = null
	bot.healer = 10.0                                   # pouca vida -> busca cura
	bot.gravidade_ativa = false
	bot.global_position = Vector3(0.0, 1.0, 0.0)
	bot._alvo = player
	falhas += _checar("bot mira o Healer com pouca vida", bot._melhor_item() == heal)
	var d_heal: float = bot.global_position.distance_to(heal.global_position)
	bot.set_physics_process(true)
	for _i in range(40):
		await get_tree().physics_frame
	falhas += _checar("bot anda em direcao ao Healer", bot.global_position.distance_to(heal.global_position) < d_heal - 1.0)
	bot.set_physics_process(false)
	bot.healer = Combatente.HEALER_MAX
	heal.queue_free()

	# Bloco B1 (Fase 4): arma de projétil.
	player.set_physics_process(false)
	bot.set_physics_process(false)
	player.healer = Combatente.HEALER_MAX
	bot.healer = Combatente.HEALER_MAX
	player.municao = player.MUNICAO_MAX
	player._cadencia_restante = 0.0
	player._recarga_restante = 0.0
	player._imobilizado_restante = 0.0              # limpa resíduo do teste do Gás
	player._slow_restante = 0.0
	player.global_position = Vector3(0.0, 1.0, 0.0)
	player.rotation.y = 0.0                          # encara -Z
	bot.global_position = Vector3(0.0, 1.0, -3.0)    # 3u na frente do player
	var mun_pre: int = player.municao
	var vida_bot_tiro: float = bot.healer
	player.atirar()
	falhas += _checar("tiro consome municao", player.municao == mun_pre - 1)
	for _i in range(40):
		await get_tree().physics_frame
	falhas += _checar("projetil acerta o inimigo (dano)", bot.healer < vida_bot_tiro)
	# Recarga: zera a munição e confirma que trava o tiro.
	player.municao = 1
	player._cadencia_restante = 0.0
	player._recarga_restante = 0.0
	player.atirar()                                  # munição -> 0, inicia recarga
	falhas += _checar("municao zera dispara recarga", player.esta_recarregando())
	var mun_durante: int = player.municao
	player._cadencia_restante = 0.0
	player.atirar()                                  # não deve atirar recarregando
	falhas += _checar("nao atira durante a recarga", player.municao == mun_durante)

	# Bloco B2 (Fase 4): corpo a corpo (knockdown).
	player.healer = Combatente.HEALER_MAX
	bot.healer = Combatente.HEALER_MAX
	player._soco_cd = 0.0
	player._derrubado_restante = 0.0
	player._imobilizado_restante = 0.0
	bot._derrubado_restante = 0.0
	player.global_position = Vector3(0.0, 1.0, 0.0)
	bot.global_position = Vector3(0.0, 1.0, -1.2)    # colado, na frente
	var vida_bot_soco: float = bot.healer
	player.socar()
	falhas += _checar("soco de perto da dano", bot.healer < vida_bot_soco)
	falhas += _checar("soco derruba o inimigo", bot.esta_derrubado())
	# Longe não acerta.
	player._soco_cd = 0.0
	bot._derrubado_restante = 0.0
	bot._impulso = Vector3.ZERO
	bot.global_position = Vector3(0.0, 1.0, -6.0)
	var vida_bot_longe: float = bot.healer
	player.socar()
	falhas += _checar("soco longe nao acerta", is_equal_approx(bot.healer, vida_bot_longe))

	# Bloco B3 (Fase 4): Unit (Plasma) — a super.
	player._derrubado_restante = 0.0
	player._imobilizado_restante = 0.0
	player.conceder_unit(1)
	falhas += _checar("conceder unit da plasma bomb", player.tem_unit and player.plasma_bombs == 1)
	player.iniciar_carga_unit()
	falhas += _checar("inicia a carga da unit", player.esta_carregando_unit())
	player.receber_dano(1.0)
	falhas += _checar("dano cancela a carga (nao dispara)", not player.esta_carregando_unit())
	# Knockdown durante a carga quebra o lançador.
	player.iniciar_carga_unit()
	player.derrubar(Vector3.FORWARD, 0.0)
	falhas += _checar("derrubado na carga quebra o lancador", not player.tem_unit)
	player._derrubado_restante = 0.0
	# Carga completa dispara a Plasma teleguiada e ela acerta o inimigo (dano massivo).
	player.conceder_unit(1)
	player.healer = Combatente.HEALER_MAX
	bot.healer = Combatente.HEALER_MAX
	bot._derrubado_restante = 0.0
	player.global_position = Vector3(0.0, 1.0, 0.0)
	player.rotation.y = 0.0
	bot.global_position = Vector3(0.0, 1.0, -3.0)
	var vida_bot_plasma: float = bot.healer
	player.iniciar_carga_unit()
	player._carga_restante = 0.02              # força a carga a completar no próximo frame
	for _i in range(90):
		await get_tree().physics_frame
	falhas += _checar("carga completa gasta a plasma bomb", player.plasma_bombs == 0)
	falhas += _checar("plasma persegue e da dano massivo", bot.healer <= vida_bot_plasma - 30.0)

	# Bloco B4 (Fase 4): Vault, itens e Spark Bit.
	var ItemCena := preload("res://scenes/items/item.tscn")
	var vault_b: Node = arena._colocar_vault(Vector2i(2, 10))
	await get_tree().physics_frame  # _ready da Vault marca o tile
	falhas += _checar("vault bloqueia plantio no tile", not GridManager.pode_plantar(Vector2i(2, 10)))
	# Speed Up dobra a velocidade.
	player._speed_restante = 0.0
	player._slow_restante = 0.0
	var it_speed := ItemCena.instantiate()
	it_speed.tipo = "speed"
	it_speed._aplicar(player)
	it_speed.free()
	falhas += _checar("speed up acelera o player", player.fator_velocidade() > 1.5)
	# Healer cura.
	player.healer = 50.0
	var it_heal := ItemCena.instantiate()
	it_heal.tipo = "healer"
	it_heal._aplicar(player)
	it_heal.free()
	falhas += _checar("item healer cura", player.healer > 50.0)
	# Protect bloqueia dano normal, mas não a Plasma.
	var it_prot := ItemCena.instantiate()
	it_prot.tipo = "protect"
	it_prot._aplicar(player)
	it_prot.free()
	player.healer = 100.0
	player.receber_dano(20.0, "normal")
	falhas += _checar("protect bloqueia dano normal", is_equal_approx(player.healer, 100.0))
	player.receber_dano(20.0, "plasma")
	falhas += _checar("protect nao bloqueia a plasma", player.healer < 100.0)
	player._protegido_restante = 0.0
	# Item de armadilha soma no inventário.
	player.inventario["bomba"] = 0
	var it_arm := ItemCena.instantiate()
	it_arm.tipo = "armadilha"
	it_arm.tipo_armadilha = "bomba"
	it_arm._aplicar(player)
	it_arm.free()
	falhas += _checar("item de armadilha soma no inventario", int(player.inventario["bomba"]) == 1)
	# Item Unit concede a Unit.
	player.tem_unit = false
	player.plasma_bombs = 0
	var it_unit := ItemCena.instantiate()
	it_unit.tipo = "unit"
	it_unit._aplicar(player)
	it_unit.free()
	falhas += _checar("item unit concede a unit", player.tem_unit and player.plasma_bombs == 1)
	# Spark Bit dá dano ao tocar.
	var spark := preload("res://scenes/items/spark_bit.tscn").instantiate()
	arena.add_child(spark)
	bot.healer = 100.0
	spark._ao_corpo_entrar(bot)
	falhas += _checar("spark bit da dano ao tocar", bot.healer < 100.0)
	# Spark Bit morre com EXPLOSÃO (manual: só bomba mata) e regenera depois.
	falhas += _checar("spark bit comeca vivo", not spark.esta_morto())
	spark.receber_dano(999.0)
	falhas += _checar("spark bit morre com explosao", spark.esta_morto())
	spark._renascer()
	falhas += _checar("spark bit regenera", not spark.esta_morto())
	spark.queue_free()
	vault_b.queue_free()

	# Bloco C1 (Fase 5): StatsPersonagem aplica vida/velocidade/munição/loadout.
	var sp := preload("res://scripts/stats_personagem.gd").new()
	sp.vida_max = 130.0
	sp.velocidade = 4.0
	sp.municao_max = 8
	sp.loadout = {"mina": 5, "gas": 1}
	var p_teste := preload("res://scenes/characters/player.tscn").instantiate()
	p_teste.stats = sp
	arena.add_child(p_teste)
	await get_tree().physics_frame  # roda o _ready (aplica stats + loadout)
	falhas += _checar("stats aplica vida_max", is_equal_approx(p_teste.vida_max, 130.0))
	falhas += _checar("stats aplica velocidade", is_equal_approx(p_teste.velocidade_base, 4.0))
	falhas += _checar("stats aplica municao_max", p_teste.municao_max == 8)
	falhas += _checar("loadout define o inventario", int(p_teste.inventario["mina"]) == 5 and int(p_teste.inventario["gas"]) == 1)
	falhas += _checar("loadout zera tipos fora dele", int(p_teste.inventario["bomba"]) == 0)
	p_teste.queue_free()

	# Bloco C2 (Fase 5): os 6 personagens carregam com os loadouts da seção 4 do GDD.
	var roster := {
		"brecht": {"vida": 100.0, "traps": {"mina": 4, "bomba": 4, "detonador": 1}},
		"magnus": {"vida": 130.0, "traps": {"bomba": 6, "detonador": 2, "gas": 2}},
		"vesna": {"vida": 100.0, "traps": {"mina": 5, "painel": 3, "gas": 1}},
		"pip": {"vida": 100.0, "traps": {"cova": 4, "painel": 4, "detonador": 3}},
		"kestrel": {"vida": 75.0, "traps": {"mina": 2, "cova": 3, "painel": 2}},
		"mara": {"vida": 100.0, "traps": {"cova": 6, "gas": 2, "mina": 3}},
	}
	for nome in roster:
		var st: Resource = load("res://resources/personagens/%s.tres" % nome)
		var pc := preload("res://scenes/characters/player.tscn").instantiate()
		pc.stats = st
		arena.add_child(pc)
		await get_tree().physics_frame
		var esp: Dictionary = roster[nome]
		var ok: bool = is_equal_approx(pc.vida_max, float(esp["vida"]))
		for tipo in esp["traps"]:
			if int(pc.inventario.get(tipo, 0)) != int(esp["traps"][tipo]):
				ok = false
		falhas += _checar("roster %s: vida e loadout corretos" % nome, ok)
		pc.queue_free()

	# Bloco C3 (Fase 5): seleção aplica o personagem em runtime.
	var st_kestrel: Resource = load("res://resources/personagens/kestrel.tres")
	player.aplicar_personagem(st_kestrel)
	falhas += _checar("aplicar_personagem troca a vida", is_equal_approx(player.vida_max, 75.0))
	falhas += _checar("aplicar_personagem troca a velocidade", is_equal_approx(player.velocidade_base, 9.0))
	falhas += _checar("aplicar_personagem refaz o loadout", int(player.inventario["mina"]) == 2 and int(player.inventario["cova"]) == 3)
	GameManager.personagem_jogador = "res://resources/personagens/vesna.tres"
	GameManager.personagem_bot = "res://resources/personagens/mara.tres"
	falhas += _checar("GameManager guarda os personagens escolhidos", GameManager.personagem_jogador.ends_with("vesna.tres") and GameManager.personagem_bot.ends_with("mara.tres"))
	GameManager.personagem_jogador = ""
	GameManager.personagem_bot = ""

	# Bloco D1 (Fase 6): mapa por dados redimensiona o grid.
	var mp: Resource = preload("res://scripts/stats_mapa.gd").new()
	mp.largura = 16
	mp.altura = 10
	mp.tamanho_tile = 2.0
	GridManager.configurar_mapa(mp)
	falhas += _checar("mapa redimensiona o grid", GridManager.LARGURA == 16 and GridManager.ALTURA == 10)
	falhas += _checar("grid_to_world usa o novo tamanho", is_equal_approx(GridManager.grid_to_world(Vector2i(0, 0)).x, -15.0))
	var mp_pad: Resource = preload("res://scripts/stats_mapa.gd").new()
	GridManager.configurar_mapa(mp_pad)
	falhas += _checar("restaura grid 12x12", GridManager.LARGURA == 12 and is_equal_approx(GridManager.grid_to_world(Vector2i(0, 0)).x, -11.0))

	# Bloco D2 (Fase 6): field traps.
	# Obstacle Box: ao quebrar, solta um item.
	var n_itens: int = get_tree().get_nodes_in_group("itens").size()
	var cx_obs := preload("res://scenes/field_traps/caixa.tscn").instantiate()
	cx_obs.tipo = "obstaculo"
	cx_obs.item_escondido = "healer"
	arena.add_child(cx_obs)
	cx_obs.global_position = Vector3(-8.0, 1.0, -8.0)
	cx_obs.receber_dano(99.0)
	falhas += _checar("obstacle box solta item ao quebrar", get_tree().get_nodes_in_group("itens").size() > n_itens)
	# Bomb Box: ao quebrar, explode e dá dano em área.
	bot.healer = Combatente.HEALER_MAX
	var cx_bomb := preload("res://scenes/field_traps/caixa.tscn").instantiate()
	cx_bomb.tipo = "bomba"
	arena.add_child(cx_bomb)
	cx_bomb.global_position = Vector3(-6.0, 1.0, -6.0)
	bot.global_position = Vector3(-6.0, 1.0, -6.0)
	cx_bomb.receber_dano(99.0)
	falhas += _checar("bomb box explode e da dano", bot.healer < Combatente.HEALER_MAX)
	# Lançador: dispara projétil.
	var n_proj: int = get_tree().get_nodes_in_group("projeteis").size()
	var lan := preload("res://scenes/field_traps/lancador.tscn").instantiate()
	arena.add_child(lan)
	lan.global_position = Vector3(7.0, 1.0, 7.0)
	lan._disparar_laser()
	falhas += _checar("lancador dispara projetil", get_tree().get_nodes_in_group("projeteis").size() > n_proj)
	lan.queue_free()
	# Esteira: empurra quem está em cima.
	var est := preload("res://scenes/field_traps/esteira.tscn").instantiate()
	est.direcao = Vector3(1, 0, 0)
	est.velocidade = 6.0
	arena.add_child(est)
	est.global_position = Vector3(0.0, 0.5, 0.0)
	bot.global_position = Vector3(0.0, 1.0, 0.0)
	var bot_x: float = bot.global_position.x
	for _i in range(20):
		await get_tree().physics_frame
	falhas += _checar("esteira empurra o combatente", bot.global_position.x > bot_x + 0.1)
	est.queue_free()

	# Bloco D3 (Fase 6): ponte dissolve a Plasma (e quebra junto).
	var ponte := preload("res://scenes/field_traps/ponte.tscn").instantiate()
	arena.add_child(ponte)
	ponte.global_position = Vector3(3.0, 1.0, 3.0)
	var pl := preload("res://scenes/projeteis/plasma.tscn").instantiate()
	pl.alvo = null
	pl.dono_id = 1
	arena.add_child(pl)
	pl.global_position = Vector3(3.0, 1.0, 3.0)   # sobre a ponte
	for _i in range(5):
		await get_tree().physics_frame
	falhas += _checar("ponte dissolve a plasma", not is_instance_valid(pl))
	falhas += _checar("plasma quebra a ponte", not is_instance_valid(ponte))

	# Bloco D4 (Fase 6): os 3 mapas têm field traps e a arena os instancia.
	for nome_mapa in ["padrao", "corredor", "fortaleza"]:
		var m: Resource = load("res://resources/mapas/%s.tres" % nome_mapa)
		var n_destr: int = get_tree().get_nodes_in_group("destrutiveis").size()
		var n_pontes: int = get_tree().get_nodes_in_group("pontes").size()
		arena._colocar_field_traps(m)
		await get_tree().physics_frame
		var ok: bool = get_tree().get_nodes_in_group("destrutiveis").size() > n_destr \
			and get_tree().get_nodes_in_group("pontes").size() > n_pontes
		falhas += _checar("mapa %s instancia field traps" % nome_mapa, ok)
	# Limpa os field traps de teste pra não poluir o resto.
	for grupo in ["destrutiveis", "esteiras", "pontes"]:
		for n in get_tree().get_nodes_in_group(grupo):
			n.queue_free()
	await get_tree().physics_frame

	# Bloco E1 (Fase 7): AudioManager toca sons (placeholders procedurais).
	falhas += _checar("audiomanager registra os sons", AudioManager.tem_som("explodir") and AudioManager.tem_som("tiro"))
	falhas += _checar("audiomanager tem som de dano e derrubado", AudioManager.tem_som("dano") and AudioManager.tem_som("derrubado"))
	falhas += _checar("audiomanager toca evento conhecido", AudioManager.tocar("explodir"))
	falhas += _checar("audiomanager ignora evento desconhecido", not AudioManager.tocar("inexistente"))

	# Bloco E2 (Fase 7): juice — screenshake + partículas de explosão + hit stop.
	var cam := arena.get_node("Camera3D")
	get_tree().call_group("camera", "tremer", 0.5)
	falhas += _checar("screenshake ativa no tremor", cam.em_tremor())
	var n_fx: int = get_tree().get_nodes_in_group("fx").size()
	var fx := preload("res://scenes/arena/explosao_fx.tscn").instantiate()
	arena.add_child(fx)
	fx.global_position = Vector3(0.0, 1.0, 0.0)
	await get_tree().process_frame
	falhas += _checar("fx de explosao entra no grupo", get_tree().get_nodes_in_group("fx").size() > n_fx and fx.emitting)
	falhas += _checar("fx de explosao tem luz", fx.get_node_or_null("Luz") != null)
	fx.queue_free()
	# Hit stop: congela o tempo por um instante e SEMPRE volta ao normal.
	GameManager.hit_stop(0.1, 0.05)
	falhas += _checar("hit stop desacelera o tempo", Engine.time_scale < 1.0)
	await get_tree().create_timer(0.3, true, false, true).timeout  # timer ignora time_scale
	falhas += _checar("hit stop restaura o tempo", is_equal_approx(Engine.time_scale, 1.0))

	# Bloco E3 (Fase 7): menus — pausa alterna o estado. (Sem await com a árvore pausada!)
	var pausa := preload("res://scenes/ui/pausa.tscn").instantiate()
	arena.add_child(pausa)
	pausa.alternar()
	falhas += _checar("pausa ativa o paused", get_tree().paused)
	pausa.alternar()
	falhas += _checar("pausa desativa o paused", not get_tree().paused)
	pausa.queue_free()

	# Bloco E4 (Fase 7): modos — VS MAN cria um 2º jogador no gamepad 1.
	GameManager.modo = "vs_man"
	falhas += _checar("gamemanager guarda o modo", GameManager.modo == "vs_man")
	var p2 := preload("res://scenes/characters/player.tscn").instantiate()
	p2.jogador_num = 2
	arena.add_child(p2)
	await get_tree().physics_frame
	falhas += _checar("player 2 usa gamepad 1 (sem teclado)", p2._gamepad == 1 and not p2._usa_teclado)
	p2.queue_free()
	GameManager.modo = "vs_com"  # restaura o default

	# Bloco E5 (Fase 7): radar mapeia o mundo pro minimapa.
	var radar: Control = preload("res://scenes/ui/radar.gd").new()
	var meio: Vector2 = radar.mundo_para_radar(Vector3(0.0, 0.0, 0.0), Vector2(100.0, 100.0))
	falhas += _checar("radar mapeia o centro pro meio", meio.is_equal_approx(Vector2(50.0, 50.0)))
	radar.free()

	# Bloco F1 (Fase 8): persistência local (salva e relê do disco).
	Persistencia.set_config("teste", "x", 42)
	Persistencia.salvar()
	Persistencia.carregar()
	falhas += _checar("persistencia salva e le do disco", int(Persistencia.get_config("teste", "x", 0)) == 42)

	# Settings (Fase 7): volume aplica no AudioManager e persiste.
	AudioManager.aplicar_volume(0.5)
	falhas += _checar("audiomanager aplica volume", absf(AudioManager.volume - 0.5) < 0.01)
	Persistencia.set_config("audio", "volume", 0.5)
	Persistencia.salvar()
	Persistencia.carregar()
	falhas += _checar("settings persiste o volume", absf(float(Persistencia.get_config("audio", "volume", 1.0)) - 0.5) < 0.01)
	AudioManager.aplicar_volume(0.8)

	# Encaixe do modelo 3D: com cena_modelo setada, esconde a cápsula e monta o "Modelo".
	var sp_mod := preload("res://scripts/stats_personagem.gd").new()
	sp_mod.cena_modelo = preload("res://scenes/arena/explosao_fx.tscn")  # qualquer cena serve de teste
	var p_mod := preload("res://scenes/characters/player.tscn").instantiate()
	p_mod.stats = sp_mod
	arena.add_child(p_mod)
	await get_tree().physics_frame
	falhas += _checar("modelo: monta o no Modelo", p_mod.get_node_or_null("Modelo") != null)
	falhas += _checar("modelo: esconde a capsula placeholder", not p_mod.get_node("Malha").visible)
	p_mod.queue_free()

	# Greybox vertical: gravidade + colisão (chão e ponte elevada).
	player.global_position = Vector3(40.0, 1.0, 40.0)   # tira os principais da área de teste
	bot.global_position = Vector3(-40.0, 1.0, -40.0)
	var chao_g: Node = arena._caixa_solida(Vector3(0.0, -0.1, 0.0), Vector3(24.0, 0.2, 24.0), Color(0.1, 0.1, 0.1))
	var pg := preload("res://scenes/characters/player.tscn").instantiate()
	pg.gravidade_ativa = true
	arena.add_child(pg)
	pg.global_position = Vector3(0.0, 5.0, 0.0)         # cai no chão
	var ponte_g: Node = arena._caixa_solida(Vector3(6.0, 2.6, 0.0), Vector3(4.0, 0.3, 4.0), Color(0.5, 0.5, 0.6))
	var pb := preload("res://scenes/characters/player.tscn").instantiate()
	pb.gravidade_ativa = true
	arena.add_child(pb)
	pb.global_position = Vector3(6.0, 5.0, 0.0)         # cai EM CIMA da ponte
	for _i in range(70):
		await get_tree().physics_frame
	falhas += _checar("gravidade assenta no chao (y~1)", absf(pg.global_position.y - 1.0) < 0.35)
	falhas += _checar("personagem fica EM CIMA da ponte (y~3.75)", absf(pb.global_position.y - 3.75) < 0.5)
	pg.queue_free()
	pb.queue_free()
	chao_g.queue_free()
	ponte_g.queue_free()

	# Oclusão da ponte: sólida sem ninguém embaixo, some quando alguém passa por baixo.
	arena._pontes.clear()
	var ponte_oc: Node = arena._construir_ponte(Vector3(15.0, 2.6, 15.0), Vector3(4.0, 0.3, 4.0))
	var mat_oc: StandardMaterial3D = arena._pontes[-1]["mat"]
	mat_oc.albedo_color.a = 1.0
	for _i in range(10):
		await get_tree().process_frame          # ninguém embaixo: continua sólida
	falhas += _checar("ponte solida sem ninguem embaixo", mat_oc.albedo_color.a > 0.8)
	var pu := preload("res://scenes/characters/player.tscn").instantiate()
	arena.add_child(pu)
	pu.set_physics_process(false)
	pu.global_position = Vector3(15.0, 1.0, 15.0)   # embaixo da ponte
	for _i in range(30):
		await get_tree().process_frame          # fade pra transparente
	falhas += _checar("ponte fica transparente com alguem embaixo", mat_oc.albedo_color.a < 0.6)
	pu.queue_free()
	ponte_oc.queue_free()
	arena._pontes.clear()

	# Arena vertical por dados: a flag e as estruturas do .tres.
	var mapa_v: Resource = load("res://resources/mapas/vertical.tres")
	falhas += _checar("mapa vertical tem a flag e estruturas", mapa_v.vertical and mapa_v.estruturas.size() > 10)
	arena._montar_arena_vertical()
	falhas += _checar("arena vertical registra 2 pontes", arena._pontes.size() == 2)
	var pv := preload("res://scenes/characters/player.tscn").instantiate()
	pv.gravidade_ativa = true
	arena.add_child(pv)
	pv.global_position = Vector3(-11.0, 5.0, 11.0)   # cai num canto livre do chão
	for _i in range(70):
		await get_tree().physics_frame
	falhas += _checar("player assenta no chao da arena vertical", absf(pv.global_position.y - 1.0) < 0.4)
	pv.queue_free()
	for n in get_tree().get_nodes_in_group("geometria"):
		n.queue_free()
	arena._pontes.clear()
	await get_tree().physics_frame

	# Reset de round: reiniciar() restaura vida/munição e limpa status; limpar_armadilhas zera o grid.
	player.healer = 20.0
	player._imobilizado_restante = 5.0
	player.municao = 1
	player.reiniciar()
	falhas += _checar("reiniciar restaura vida e municao", is_equal_approx(player.healer, player.vida_max) and player.municao == player.municao_max)
	falhas += _checar("reiniciar limpa o status", not player.esta_imobilizado())
	GridManager.remover_armadilha(Vector2i(5, 5))
	player.inventario["mina"] = 4
	player.global_position = GridManager.grid_to_world(Vector2i(5, 5))
	player.plantar("mina")
	falhas += _checar("tem armadilha antes de limpar", GridManager.tem_armadilha(Vector2i(5, 5)))
	GridManager.limpar_armadilhas()
	falhas += _checar("limpar_armadilhas zera o grid", not GridManager.tem_armadilha(Vector2i(5, 5)))

	# Câmera segue o player (mapas grandes Trap Gunner).
	var cam_t := arena.get_node_or_null("Camera3D") as Camera3D
	if cam_t != null:
		var pos_orig := cam_t.position
		arena._cam_offset = cam_t.position
		arena._seguir_camera = true
		player.global_position = Vector3(20.0, 1.0, -10.0)
		for _i in range(80):
			arena._seguir_player(0.05)
		falhas += _checar("camera segue o X do player", absf(cam_t.global_position.x - 20.0) < 0.6)
		falhas += _checar("camera segue o Z do player", absf(cam_t.global_position.z - 5.0) < 0.6)
		arena._seguir_camera = false
		cam_t.position = pos_orig

	# Mapa grande Setor 07 (Trap Gunner): carrega, é grande, pede câmera-segue e tem estruturas.
	var m_setor: Resource = load("res://resources/mapas/setor07.tres")
	falhas += _checar("setor07 carrega grande", m_setor.largura >= 30 and m_setor.altura >= 30)
	falhas += _checar("setor07 pede camera-segue e vertical", m_setor.camera_segue and m_setor.vertical)
	falhas += _checar("setor07 tem muitas estruturas", m_setor.estruturas.size() > 10)

	# G3: regras de partida em ROUNDS (melhor de 3). Sem listener da arena no --teste,
	# então reseto os Healers manualmente entre os rounds.
	player.set_physics_process(false)
	bot.set_physics_process(false)
	player.healer = Combatente.HEALER_MAX
	bot.healer = Combatente.HEALER_MAX
	GameManager.iniciar_partida([player, bot])
	falhas += _checar("partida comeca em 90s no round 1", is_equal_approx(GameManager.tempo_restante, 90.0) and GameManager.round_num == 1)
	falhas += _checar("placar comeca 0-0", GameManager.v1 == 0 and GameManager.v2 == 0)
	var venceu := { "id": -1 }
	GameManager.partida_acabou.connect(func(vid: int, _m: String): venceu["id"] = vid)
	bot.receber_dano(999.0)                       # round 1 -> jogador
	falhas += _checar("round 1 vai pro jogador (1-0)", GameManager.v1 == 1 and GameManager.v2 == 0)
	falhas += _checar("partida NAO acaba no round 1", venceu["id"] == -1)
	GameManager._process(GameManager.PAUSA_ENTRE_ROUNDS + 0.1)  # passa a pausa -> round 2
	falhas += _checar("avanca automaticamente pro round 2", GameManager.round_num == 2)
	player.healer = Combatente.HEALER_MAX
	bot.healer = Combatente.HEALER_MAX
	bot.receber_dano(999.0)                       # round 2 -> jogador faz 2 -> vence a partida
	falhas += _checar("placar fica 2-0", GameManager.v1 == 2)
	falhas += _checar("jogador vence a PARTIDA com 2 rounds", venceu["id"] == 1)

	# Story — objetivo "desarmes": N desarmes bem-sucedidos vencem a PARTIDA na hora.
	GameManager.objetivo = "desarmes"
	GameManager.objetivo_meta = 2
	GameManager.story_missao = -1
	player.healer = Combatente.HEALER_MAX
	bot.healer = Combatente.HEALER_MAX
	GameManager.iniciar_partida([player, bot])
	var venceu_obj := { "id": -1 }
	GameManager.partida_acabou.connect(func(vid: int, _m: String): venceu_obj["id"] = vid)
	GameManager._ao_desarme_p1(true)
	falhas += _checar("objetivo desarmes: 1/2 nao vence", venceu_obj["id"] == -1)
	GameManager._ao_desarme_p1(true)
	falhas += _checar("objetivo desarmes: 2/2 vence a partida", venceu_obj["id"] == 1)
	# Story — objetivo "sobreviver": no fim do tempo, o jogador vivo vence o round.
	GameManager.objetivo = "sobreviver"
	player.healer = 5.0
	bot.healer = Combatente.HEALER_MAX
	GameManager.iniciar_partida([player, bot])
	GameManager._decidir_por_tempo()
	falhas += _checar("objetivo sobreviver: vivo no fim -> round do jogador", GameManager.v1 == 1)
	GameManager.objetivo = ""
	GameManager.objetivo_meta = 3

	# Pathfinding A* (IA): com um tile sólido no meio, a rota existe e CONTORNA.
	GridManager.configurar_mapa(preload("res://scripts/stats_mapa.gd").new())
	GridManager.marcar_solido(Vector2i(6, 6), true)
	var rota: Array = GridManager.caminho_mundo(
		GridManager.grid_to_world(Vector2i(5, 6)), GridManager.grid_to_world(Vector2i(7, 6)))
	falhas += _checar("astar: acha rota com obstaculo", not rota.is_empty())
	var pisou_solido := false
	for pr in rota:
		if GridManager.world_to_grid(pr) == Vector2i(6, 6):
			pisou_solido = true
	falhas += _checar("astar: rota contorna o tile solido", not pisou_solido)
	GridManager.marcar_solido(Vector2i(6, 6), false)

	# Split-screen (VS MAN): monta 2 viewports compartilhando o mundo + 2 câmeras.
	arena._montar_split_screen(player, bot)
	falhas += _checar("split: monta o no SplitScreen", arena.get_node_or_null("SplitScreen") != null)
	falhas += _checar("split: 2 cameras seguindo alvos", arena._cams_split.size() == 2)
	arena.get_node("SplitScreen").queue_free()
	arena._cams_split.clear()
	(arena.get_node("Camera3D") as Camera3D).current = true
	await get_tree().physics_frame

	# Cannon (FAQ): o míssil teleguiado curva atrás do alvo. Lançado pra +Z com o alvo a +X,
	# após alguns passos a velocidade deve ter ganhado componente +X (virou pro alvo).
	var alvo_no := Node3D.new()
	arena.add_child(alvo_no)
	alvo_no.global_position = Vector3(10.0, 1.0, 0.0)
	var miss: Node = preload("res://scenes/projeteis/projetil.tscn").instantiate()
	arena.add_child(miss)
	miss.global_position = Vector3(0.0, 1.0, 0.0)
	miss.velocidade = Vector3(0.0, 0.0, 6.0)   # 90° do alvo
	miss.vida = 999.0                          # não expira durante o teste
	miss.teleguiado = true
	miss.alvo = alvo_no
	for _i in range(20):
		miss._physics_process(0.05)
	falhas += _checar("cannon: missil teleguiado curva pro alvo (+X)", miss.velocidade.x > 1.0)
	miss.queue_free()
	alvo_no.queue_free()

	if falhas == 0:
		print("[TESTE] RESULTADO: TODOS OS TESTES PASSARAM")
	else:
		print("[TESTE] RESULTADO: %d FALHA(S)" % falhas)
	get_tree().quit()


# ───────────────────────────── Demos de captura (dev) ─────────────────────────────

## Gera os RETRATOS oficiais do roster (assets/sprites/retratos/<nome>.png, 256×256):
## renderiza cada modelo 3D em close 3/4 contra um pano na cor do personagem.
## Substitui os banners promocionais de terceiros — arte de retrato própria do jogo.
func _gerar_retratos() -> void:
	player.visible = false
	bot.visible = false
	player.set_physics_process(false)
	bot.set_physics_process(false)
	var hud := arena.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	var cam := arena.get_node("Camera3D") as Camera3D
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 28.0
	var base := Vector3(400.0, 0.0, 400.0)   # bem longe do mapa
	for nome in ["brecht", "magnus", "vesna", "pip", "kestrel", "mara"]:
		var st: Resource = load("res://resources/personagens/%s.tres" % nome)
		if st == null or st.cena_modelo == null:
			continue
		var m: Node3D = st.cena_modelo.instantiate()
		arena.add_child(m)
		m.global_position = base
		# 3/4 de frente (o modelo cru olha +Z; giro de 180+25 = de frente, virado de leve).
		m.rotation.y = deg_to_rad(180.0 + 25.0)
		var alt := _altura_modelo_cru(m)
		# Pano de fundo na cor do personagem (escura — o rosto é quem brilha).
		var pano := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(8.0, 8.0)
		pm.orientation = PlaneMesh.FACE_Z
		pano.mesh = pm
		var c: Color = st.cor_time
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(c.r * 0.4, c.g * 0.4, c.b * 0.4)
		pano.material_override = mat
		arena.add_child(pano)
		pano.global_position = base + Vector3(0.0, alt * 0.5, 2.2)   # atrás (modelo olha -Z)
		# Luz de estúdio: key frontal alta + fill lateral (o rosto é o assunto).
		var key := OmniLight3D.new()
		key.light_energy = 2.2
		key.omni_range = 12.0
		key.shadow_enabled = false
		arena.add_child(key)
		key.global_position = base + Vector3(-1.2, alt * 1.1, -alt * 1.4)
		var fill := OmniLight3D.new()
		fill.light_energy = 1.0
		fill.light_color = Color(c.r, c.g, c.b).lerp(Color.WHITE, 0.5)
		fill.omni_range = 12.0
		fill.shadow_enabled = false
		arena.add_child(fill)
		fill.global_position = base + Vector3(1.6, alt * 0.6, -alt * 1.0)
		# Câmera na frente (-Z), na altura dos olhos, close no rosto/ombros.
		# Enquadramento POR PERSONAGEM (frações da altura: câmera, olhar, distância) —
		# a família Quaternius tem proporções humanas: rosto a ~90% da altura.
		var enq: Array = {
		}.get(nome, [0.88, 0.82, 0.62])
		cam.global_position = base + Vector3(0.0, alt * float(enq[0]), -alt * float(enq[2]))
		cam.look_at(base + Vector3(0.0, alt * float(enq[1]), 0.0), Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		# Recorta o quadrado central e reduz pra 256 (retrato de HUD/seleção).
		var lado := mini(img.get_width(), img.get_height())
		img = img.get_region(Rect2i((img.get_width() - lado) / 2, (img.get_height() - lado) / 2, lado, lado))
		img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/sprites/retratos/%s.png" % nome)
		print("[Retratos] salvo ", nome)
		m.queue_free()
		pano.queue_free()
		key.queue_free()
		fill.queue_free()
	get_tree().quit()


## Altura crua (AABB) das malhas de um modelo recém-instanciado (escala 1).
func _altura_modelo_cru(no: Node3D) -> float:
	var minimo := 1.0e9
	var maximo := -1.0e9
	for filho in no.find_children("*", "MeshInstance3D", true, false):
		var mi := filho as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab := mi.get_aabb()
		minimo = minf(minimo, ab.position.y)
		maximo = maxf(maximo, ab.position.y + ab.size.y)
	return maxf(0.5, maximo - minimo)

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


## Planta minas do BOT ao redor do player e liga o Caution Mode dele, depois captura.
func _demo_caution_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame  # deixa o _ready terminar antes de mexer na árvore
	player.global_position = GridManager.grid_to_world(Vector2i(6, 6))
	for c in [Vector2i(6, 5), Vector2i(7, 6), Vector2i(5, 7), Vector2i(6, 9)]:
		bot.global_position = GridManager.grid_to_world(c)
		bot._tentar_plantar_mina()
	bot.global_position = Vector3(11, 1, -11)  # tira o bot de cena
	player.ativar_caution(true)
	await get_tree().physics_frame
	player._atualizar_overlay_caution()  # físicas off: força um refresh do overlay
	_capturar_e_sair()


## Liga a HUD, planta uma mina inimiga, encosta o player em Caution Mode (inicia o
## desarme) e captura — mostra o Disarming Code e os destaques azuis na tela.
func _demo_desarme_e_capturar() -> void:
	arena.get_node("HUD").configurar(player, bot)
	bot.set_physics_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	var coord := Vector2i(6, 6)
	bot.global_position = GridManager.grid_to_world(coord)
	bot._tentar_plantar_mina()
	bot.global_position = Vector3(11, 1, -11)  # tira o bot de cena
	player.global_position = GridManager.grid_to_world(coord)
	player.ativar_caution(true)
	player._ler_interacao()       # encosta -> inicia o desarme (cancela o gatilho)
	player._atualizar_overlay_caution()
	await get_tree().process_frame
	await get_tree().process_frame  # deixa a HUD desenhar o painel de código
	_capturar_e_sair()


## Demo do mapa grande Setor 07 (Trap Gunner): monta as estruturas e segue o player.
func _demo_setor07_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	var mapa: Resource = load("res://resources/mapas/setor07.tres")
	var chao := arena.get_node_or_null("Chao")
	if chao != null:
		chao.visible = false   # o chão do mapa (estrutura) cobre tudo
	player.gravidade_ativa = true
	bot.gravidade_ativa = true
	arena._montar_estruturas(mapa)
	arena._configurar_camera()
	await get_tree().physics_frame
	player.global_position = Vector3(-12.0, 1.0, 14.0)
	bot.global_position = Vector3(8.0, 1.0, 10.0)
	for _i in range(40):
		await get_tree().process_frame   # câmera converge + oclusão age
	_capturar_e_sair()


## Demo da arena vertical completa: posiciona o player numa rampa subindo e o bot no alto.
func _demo_vertical_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	arena._montar_arena_vertical()
	await get_tree().physics_frame
	player.global_position = Vector3(0.0, 1.0, 6.0)    # no chão, embaixo das pontes
	bot.global_position = Vector3(0.0, 3.6, 0.0)       # no cruzamento das pontes (alto)
	for _i in range(30):
		await get_tree().process_frame                 # deixa a oclusão agir
	_capturar_e_sair()


## Demo de mapa POVOADO (Vaults, field traps, personagens do roster) com captura —
## serve pra qualquer mapa plano (--demo-padrao, --demo-porto).
func _demo_mapa_povoado_e_capturar(caminho_mapa: String) -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	var mapa: Resource = load(caminho_mapa)
	GridManager.configurar_mapa(mapa)
	arena._montar_visual_mapa(mapa)   # chão xadrez + paredes + câmera Trap Gunner
	for c in mapa.vaults:
		arena._colocar_vault(c)
	arena._colocar_field_traps(mapa)
	# Dois personagens do roster (modelos KayKit) pra conferir escala/rotação na captura.
	player.aplicar_personagem(load("res://resources/personagens/brecht.tres"))
	bot.aplicar_personagem(load("res://resources/personagens/magnus.tres"))
	await get_tree().physics_frame
	player.global_position = GridManager.grid_to_world(Vector2i(9, 12))
	player.global_position.y = 1.0
	bot.global_position = GridManager.grid_to_world(Vector2i(12, 9))
	bot.global_position.y = 1.0
	for _i in range(40):
		await get_tree().process_frame
	_capturar_e_sair()


## Demo do greybox vertical: posiciona um no chão SOB a ponte e outro EM CIMA dela, captura.
func _demo_greybox_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	arena._construir_greybox()
	await get_tree().physics_frame
	player.global_position = Vector3(0.0, 1.0, 1.0)    # no chão, embaixo da ponte
	bot.global_position = Vector3(0.0, 3.6, 0.0)       # em cima da ponte (2.6 + 1.0)
	for _i in range(30):
		await get_tree().process_frame  # deixa a ponte esmaecer (oclusão)
	_capturar_e_sair()


## Demo do modelo 3D fallback (KayKit Knight): aplica no player e no bot e captura.
func _demo_modelo_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	var sp := preload("res://scripts/stats_personagem.gd").new()
	sp.cena_modelo = load("res://assets/models/kaykit/Knight.glb")
	sp.escala_modelo = 0.0
	sp.rotacao_modelo_y = 180.0
	sp.offset_modelo_y = -1.0
	player.aplicar_personagem(sp)
	bot.aplicar_personagem(sp)
	await get_tree().physics_frame
	player.global_position = Vector3(-1.5, 1.0, 1.5)
	bot.global_position = Vector3(1.5, 1.0, 1.5)
	var modelo := player.get_node_or_null("Modelo")
	if modelo != null:
		print("[MODELO] tamanho(x,y,z)=", _aabb_no(modelo).size, " (y maior = em pe)")
	await get_tree().process_frame
	await get_tree().process_frame
	_capturar_e_sair()


## Junta os AABB de todos os MeshInstance3D sob um nó (espaço local do nó), pra medir tamanho.
func _aabb_no(no: Node) -> AABB:
	var total := AABB()
	var achou := false
	for filho in no.find_children("*", "MeshInstance3D", true, false):
		var mi := filho as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab := mi.get_aabb()
		if not achou:
			total = ab
			achou = true
		else:
			total = total.merge(ab)
	return total


## Demo de mapa: aplica um mapa com field traps e captura (caixas/esteira/ponte/lançador).
func _demo_mapa_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	var mapa: Resource = preload("res://resources/mapas/padrao.tres")
	GridManager.configurar_mapa(mapa)
	arena._montar_visual_mapa(mapa)
	await get_tree().physics_frame
	player.global_position = GridManager.grid_to_world(mapa.spawn_jogador)
	player.global_position.y = 1.0
	bot.global_position = GridManager.grid_to_world(mapa.spawn_bot)
	bot.global_position.y = 1.0
	for c in mapa.vaults:
		arena._colocar_vault(c)
	arena._colocar_field_traps(mapa)
	await get_tree().process_frame
	await get_tree().process_frame
	_capturar_e_sair()


## Demo de combate: Vault soltando item, projétil e Plasma em voo, e HUD com Unit.
func _demo_combate_e_capturar() -> void:
	arena.get_node("HUD").configurar(player, bot)
	bot.set_physics_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	player.global_position = Vector3(-4.0, 1.0, 4.0)
	bot.global_position = Vector3(4.0, 1.0, -4.0)
	player.conceder_unit(2)                       # HUD mostra a Unit
	var vault: Node = arena._colocar_vault(Vector2i(6, 6))
	vault._soltar_item()                          # item visível na Vault
	var pr := preload("res://scenes/projeteis/projetil.tscn").instantiate()
	arena.add_child(pr); pr.global_position = Vector3(0.0, 1.0, 2.0)
	var pl := preload("res://scenes/projeteis/plasma.tscn").instantiate()
	pl.alvo = null
	arena.add_child(pl); pl.global_position = Vector3(-1.0, 1.0, -1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_capturar_e_sair()


## Liga a HUD e abre o menu radial com uma fatia destacada, depois captura.
func _demo_radial_e_capturar() -> void:
	arena.get_node("HUD").configurar(player, bot)
	bot.set_physics_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	player.global_position = GridManager.grid_to_world(Vector2i(6, 6))
	player._radial_aberto = true
	player._radial_idx = 3        # destaca o Gás na roda
	await get_tree().process_frame
	await get_tree().process_frame
	_capturar_e_sair()


## Demo da tela de fim de partida (vitória premium).
func _demo_fim_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	arena.get_node("HUD").configurar(player, bot)
	await get_tree().physics_frame
	arena.get_node("HUD")._ao_partida_acabar(1, "Healer zerado")
	await get_tree().process_frame
	await get_tree().process_frame
	_capturar_e_sair()
