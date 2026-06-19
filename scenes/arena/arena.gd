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
	# Demo do Caution Mode: minas inimigas + player em busca (highlights + marcadores).
	if "--demo-caution" in args:
		_demo_caution_e_capturar()
		return
	# Demo do desarme: player encostando numa mina inimiga, HUD mostrando o código.
	if "--demo-desarme" in args:
		_demo_desarme_e_capturar()
		return
	# Demo do menu radial: a roda das 6 armadilhas aberta com uma fatia destacada.
	if "--demo-radial" in args:
		_demo_radial_e_capturar()
		return
	# Demo de combate: Vault com item, projétil e Plasma em voo, HUD de munição/Unit.
	if "--demo-combate" in args:
		_demo_combate_e_capturar()
		return
	# Modo captura automatizada (screenshot pro dev). Só roda se passado --capturar.
	if "--capturar" in args:
		_capturar_e_sair()
		return
	# Mapa por dados (Fase 6): redimensiona o grid, redesenha, posiciona spawns e Vaults.
	var mapa: Resource = preload("res://resources/mapas/padrao.tres")
	GridManager.configurar_mapa(mapa)
	_desenhar_grid()
	player.global_position = GridManager.grid_to_world(mapa.spawn_jogador)
	player.global_position.y = 1.0
	bot.global_position = GridManager.grid_to_world(mapa.spawn_bot)
	bot.global_position.y = 1.0
	# Personagens escolhidos na tela de seleção (se houver).
	if GameManager.personagem_jogador != "":
		player.aplicar_personagem(load(GameManager.personagem_jogador))
	if GameManager.personagem_bot != "":
		bot.aplicar_personagem(load(GameManager.personagem_bot))
	# Modo normal de jogo: liga a HUD e inicia a partida (timer + regras de vitória).
	$HUD.configurar(player, bot)
	for c in mapa.vaults:
		_colocar_vault(c)                           # Vaults do mapa (GDD 8)
	GameManager.faltam_30s.connect(_ao_faltar_30s)  # Spark Bit aos 30s (GDD 7.3)
	GameManager.iniciar_partida([player, bot])


## Instancia uma Vault no centro de um tile (cospe itens durante a partida).
## Define a posição ANTES do add_child pro _ready da Vault ler o tile certo.
func _colocar_vault(coord: Vector2i) -> Node:
	var v := preload("res://scenes/items/vault.tscn").instantiate()
	v.position = GridManager.grid_to_world(coord)  # arena na origem: local == mundo
	add_child(v)
	return v


## Spark Bit no centro da arena quando faltam 30s (perigo que força ação).
func _ao_faltar_30s() -> void:
	var s := preload("res://scenes/items/spark_bit.tscn").instantiate()
	add_child(s)
	s.global_position = Vector3(0.0, 1.0, 0.0)


## Por ora só registra; as regras completas de vitória vêm no bloco 5 (HUD/GameManager).
func _ao_player_morrer() -> void:
	print("[Arena] Healer do jogador zerou — fim de partida (placeholder).")


func _ao_bot_morrer() -> void:
	print("[Arena] Healer do bot zerou — jogador venceu (placeholder).")


## Desenha as linhas do grid como ImmediateMesh, em neon ciano discreto. Roda ao jogar.
func _desenhar_grid() -> void:
	var antigo := get_node_or_null("LinhasGrid")  # redesenho seguro (mapa pode mudar)
	if antigo != null:
		antigo.free()
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

	# Fase 3 bloco 3: Caution Mode (detecção da teia inimiga).
	# O bot (inimigo) planta uma mina; o player detecta dentro do alcance e só então.
	var coord_inim := Vector2i(1, 1)
	bot.global_position = GridManager.grid_to_world(coord_inim)
	bot._tentar_plantar_mina()
	falhas += _checar("bot planta mina (dono 2)", GridManager.armadilha_em(coord_inim).get("dono") == 2)
	# Player perto e em Caution Mode revela a mina inimiga.
	player.global_position = GridManager.grid_to_world(Vector2i(2, 1))  # 1 tile de distância
	player.ativar_caution(true)
	falhas += _checar("caution detecta mina inimiga no alcance", coord_inim in player.armadilhas_detectadas())
	# Planta uma mina DO PRÓPRIO player ao lado: não deve ser detectada (só a inimiga).
	player.plantar("mina")
	var coord_propria := GridManager.world_to_grid(player.global_position)
	falhas += _checar("caution ignora a propria armadilha", not (coord_propria in player.armadilhas_detectadas()))
	# Fora do alcance: nada é detectado.
	player.global_position = GridManager.grid_to_world(Vector2i(10, 10))
	falhas += _checar("caution nao detecta fora do alcance", player.armadilhas_detectadas().is_empty())
	# Soltar o botão zera a detecção.
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
	var vault_b := _colocar_vault(Vector2i(2, 10))
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
	add_child(spark)
	bot.healer = 100.0
	spark._ao_corpo_entrar(bot)
	falhas += _checar("spark bit da dano ao tocar", bot.healer < 100.0)
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
	add_child(p_teste)
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
		add_child(pc)
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
	# grid_to_world reflete o novo tamanho: canto (0,0) em x = 0.5*2 - 16*2*0.5 = -15.
	falhas += _checar("grid_to_world usa o novo tamanho", is_equal_approx(GridManager.grid_to_world(Vector2i(0, 0)).x, -15.0))
	# Restaura 12x12 pro resto do teste.
	var mp_pad: Resource = preload("res://scripts/stats_mapa.gd").new()
	GridManager.configurar_mapa(mp_pad)
	falhas += _checar("restaura grid 12x12", GridManager.LARGURA == 12 and is_equal_approx(GridManager.grid_to_world(Vector2i(0, 0)).x, -11.0))

	# Bloco 5: regras de vitória. Restaura os Healers (o bot levou as detonações do bloco 4).
	player.healer = Combatente.HEALER_MAX
	bot.healer = Combatente.HEALER_MAX
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


## Planta minas do BOT ao redor do player e liga o Caution Mode dele, depois captura.
## Mostra os destaques azuis dos tiles no alcance e os marcadores amarelos das minas.
func _demo_caution_e_capturar() -> void:
	bot.set_physics_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame  # deixa o _ready terminar antes de mexer na árvore
	player.global_position = GridManager.grid_to_world(Vector2i(6, 6))
	# Minas inimigas: algumas dentro do alcance (detectadas), uma fora (não aparece).
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
	$HUD.configurar(player, bot)
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


## Demo de combate: Vault soltando item, projétil e Plasma em voo, e HUD com Unit.
func _demo_combate_e_capturar() -> void:
	$HUD.configurar(player, bot)
	bot.set_physics_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	player.global_position = Vector3(-4.0, 1.0, 4.0)
	bot.global_position = Vector3(4.0, 1.0, -4.0)
	player.conceder_unit(2)                       # HUD mostra a Unit
	var vault := _colocar_vault(Vector2i(6, 6))
	vault._soltar_item()                          # item visível na Vault
	# Um projétil e uma Plasma "parados" pra aparecerem na foto.
	var pr := preload("res://scenes/projeteis/projetil.tscn").instantiate()
	add_child(pr); pr.global_position = Vector3(0.0, 1.0, 2.0)
	var pl := preload("res://scenes/projeteis/plasma.tscn").instantiate()
	pl.alvo = null
	add_child(pl); pl.global_position = Vector3(-1.0, 1.0, -1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_capturar_e_sair()


## Liga a HUD e abre o menu radial com uma fatia destacada, depois captura.
func _demo_radial_e_capturar() -> void:
	$HUD.configurar(player, bot)
	bot.set_physics_process(false)
	player.set_physics_process(false)
	await get_tree().physics_frame
	player.global_position = GridManager.grid_to_world(Vector2i(6, 6))
	player._radial_aberto = true
	player._radial_idx = 3        # destaca o Gás na roda
	await get_tree().process_frame
	await get_tree().process_frame
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
