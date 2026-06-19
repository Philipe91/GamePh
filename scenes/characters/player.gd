extends "res://scenes/characters/combatente.gd"
## Player — personagem jogável.
##
## Herda de Combatente (Healer, dano, knockback, grupo). Aqui fica o movimento LIVRE
## (WASD + analógico) e o sistema de armadilhas: inventário por TIPO, seleção da ativa
## e plantio com snap no tile (GDD seção 6). A seleção por menu radial entra no bloco 3;
## por ora troca-se com Q/E (teclado) só pra testar os tipos.

## Inventário de um tipo mudou (pra HUD).
signal inventario_mudou(tipo: String, atual: int, maximo: int)
## Armadilha selecionada mudou (pra HUD).
signal selecao_mudou(tipo: String)
## Caution Mode ligou/desligou (pra HUD/áudio — comunicação por signal).
signal caution_mudou(ativo: bool)
## Desarme começou (HUD mostra o código e o timer). seq = direções (0..3).
signal desarme_iniciado(seq: Array, tempo: float)
## Desarme terminou (HUD esconde o painel). sucesso true/false.
signal desarme_encerrado(sucesso: bool)

const VELOCIDADE: float = 7.0
const ZONA_MORTA: float = 0.2
## Alcance do Caution Mode em tiles (raio). 2 tiles cobrem uma vizinhança 5x5 (GDD 6.1).
const ALCANCE_CAUTION_TILES: float = 2.0
## Desarme (GDD 6.2): distância pra "encostar", tamanho do código, tempo e cura no sucesso.
const DIST_INTERACAO: float = 1.6
const DESARME_TAM: int = 4
const DESARME_TEMPO: float = 4.0
const DESARME_CURA: float = 8.0
const DESARME_COOLDOWN: float = 1.0

const CENA_ARMADILHA := preload("res://scenes/traps/armadilha.tscn")
## Stats (.tres) de cada tipo disponível. Cresce nos próximos blocos da Fase 3.
const STATS := {
	"mina": preload("res://resources/armadilhas/mina.tres"),
	"bomba": preload("res://resources/armadilhas/bomba.tres"),
	"detonador": preload("res://resources/armadilhas/detonador.tres"),
	"gas": preload("res://resources/armadilhas/gas.tres"),
	"cova": preload("res://resources/armadilhas/cova.tres"),
	"painel": preload("res://resources/armadilhas/painel.tres"),
}
## Ordem de ciclo da seleção (as 6 armadilhas — GDD seção 6).
const ORDEM: Array[String] = ["mina", "bomba", "detonador", "gas", "cova", "painel"]

var inventario: Dictionary = {}      # tipo -> quantidade disponível
var inventario_max: Dictionary = {}  # tipo -> teto (do loadout; recarga/retomada capam aqui)
var selecao: String = "mina"

var _plantar_antes: bool = false
var _detonar_antes: bool = false
var _ciclo_antes: int = 0            # borda de Q/E (-1 prev, +1 next)

# Caution Mode (GDD 6.1): segurar pra revelar a teia inimiga no alcance.
var _caution_ativo: bool = false
var _caution_no: Node3D = null               # container das malhas do overlay (em mundo)
var _caution_tiles: Array[MeshInstance3D] = []   # pool de destaques de tile (azul)
var _caution_marcas: Array[MeshInstance3D] = []  # pool de marcadores de armadilha (amarelo)

# Desarme (GDD 6.2) e retomada (GDD 6.3).
var _desarme_alvo: Node = null       # armadilha inimiga em desarme (null = sem desarme)
var _desarme_seq: Array[int] = []    # código alvo: direções 0=cima 1=baixo 2=esq 3=dir
var _desarme_idx: int = 0            # quantos botões corretos já entraram
var _desarme_tempo: float = 0.0      # tempo restante do código
var _desarme_cooldown: float = 0.0   # trava recomeço imediato após uma tentativa
var _retomada_alvo: Node = null      # própria armadilha sob o prompt de retomar
var _interagir_antes: bool = false   # borda do botão de confirmar (R / X)
var _codigo_antes: int = -1          # borda da última seta do código (-1 = nenhuma)

# Menu radial de seleção (GDD 6.4): segurar abre a roda; o direcional escolhe; soltar seleciona.
var _radial_aberto: bool = false
var _radial_idx: int = 0


func _ready() -> void:
	super._ready()
	_gamepad = jogador_num - 1          # p1 → gamepad 0, p2 → gamepad 1
	_usa_teclado = jogador_num == 1     # só o p1 usa teclado/mouse (VS MAN é 2 gamepads)
	if stats == null:
		velocidade_base = VELOCIDADE   # default do player quando não há StatsPersonagem
	for tipo in ORDEM:
		var ini := _qtd_inicial(tipo)
		inventario_max[tipo] = ini
		inventario[tipo] = ini
		inventario_mudou.emit(tipo, ini, ini)
	selecao = "mina"
	selecao_mudou.emit(selecao)
	_construir_overlay_caution()


## Quantidade inicial de um tipo: do loadout do personagem, ou o default do .tres da armadilha.
func _qtd_inicial(tipo: String) -> int:
	if stats != null and not stats.loadout.is_empty():
		return int(stats.loadout.get(tipo, 0))
	return int(STATS[tipo].inventario_inicial)


## Troca o personagem em runtime: reaplica stats (base) e refaz o inventário do loadout.
func aplicar_personagem(novo: Resource) -> void:
	super.aplicar_personagem(novo)
	inventario.clear()
	inventario_max.clear()
	for tipo in ORDEM:
		var ini := _qtd_inicial(tipo)
		inventario_max[tipo] = ini
		inventario[tipo] = ini
		inventario_mudou.emit(tipo, ini, ini)


var _escape_antes: bool = false      # borda do "mash" pra sair da Cova

## Qual jogador controla este Player: 1 = teclado + gamepad 0; 2 = gamepad 1 (VS MAN).
@export var jogador_num: int = 1
var _gamepad: int = 0
var _usa_teclado: bool = true


# ───────────────────────── Helpers de input por dispositivo ─────────────────────────
func _tecla(codigo: int) -> bool:
	return _usa_teclado and Input.is_physical_key_pressed(codigo)


func _botao(jb: int) -> bool:
	return Input.is_joy_button_pressed(_gamepad, jb)


func _eixo(ax: int) -> float:
	return Input.get_joy_axis(_gamepad, ax)


func _mouse(mb: int) -> bool:
	return _usa_teclado and Input.is_mouse_button_pressed(mb)


func _physics_process(delta: float) -> void:
	# Derrubado (knockdown): sem controle nenhum até passar (GDD 7.2).
	if esta_derrubado():
		velocity = Vector3.ZERO
		return
	if _desarme_cooldown > 0.0:
		_desarme_cooldown = maxf(0.0, _desarme_cooldown - delta)

	# Em desarme: o player fica parado, focado no código (e exposto — GDD 6.2).
	if _desarme_alvo != null:
		velocity = Vector3.ZERO
		_processar_desarme(delta)
		_ler_caution()
		_atualizar_overlay_caution()
		return

	# Menu radial aberto: player parado, o direcional só escolhe a fatia (não anda).
	_ler_radial()
	if _radial_aberto:
		velocity = Vector3.ZERO
		return

	var dir := _obter_direcao()
	if esta_imobilizado():
		# Preso (Cova/Gás): não anda; apertar direção repetidamente acelera a saída.
		velocity = Vector3.ZERO
		var mash := dir.length() > 0.01
		if mash and not _escape_antes:
			tentar_escapar(0.3)
		_escape_antes = mash
	else:
		_escape_antes = false
		var vel := velocidade_base * fator_velocidade()  # base do personagem × slow/speed
		velocity.x = dir.x * vel
		velocity.z = dir.y * vel
		if gravidade_ativa:
			# Mapa vertical: segue o chão de colisão (rampa/ponte) com gravidade.
			if not is_on_floor():
				velocity.y -= GRAVIDADE * delta
			move_and_slide()
		else:
			# Mapa plano: altura travada (comportamento original, rápido).
			velocity.y = 0.0
			move_and_slide()
			position.y = ALTURA_PISO
		if dir.length() > 0.01:
			var alvo := atan2(-velocity.x, -velocity.z)
			rotation.y = lerp_angle(rotation.y, alvo, 0.25)
	_ler_acoes()
	_ler_caution()
	_atualizar_overlay_caution()
	_ler_interacao()


func _obter_direcao() -> Vector2:
	var dir := Vector2.ZERO
	if _tecla(KEY_D):
		dir.x += 1.0
	if _tecla(KEY_A):
		dir.x -= 1.0
	if _tecla(KEY_S):
		dir.y += 1.0
	if _tecla(KEY_W):
		dir.y -= 1.0
	var gx := _eixo(JOY_AXIS_LEFT_X)
	var gy := _eixo(JOY_AXIS_LEFT_Y)
	if absf(gx) > ZONA_MORTA:
		dir.x += gx
	if absf(gy) > ZONA_MORTA:
		dir.y += gy
	return dir.limit_length(1.0)


## Lê plantar (Espaço/A), detonar (F/B) e ciclar seleção (Q/E), todos por borda.
func _ler_acoes() -> void:
	var plantar_p := _tecla(KEY_SPACE) or _botao(JOY_BUTTON_A)
	if plantar_p and not _plantar_antes:
		plantar()
	_plantar_antes = plantar_p

	var detonar_p := _tecla(KEY_F) or _botao(JOY_BUTTON_B)
	if detonar_p and not _detonar_antes:
		acionar_detonadores()
	_detonar_antes = detonar_p

	var ciclo := 0
	if _tecla(KEY_E):
		ciclo = 1
	elif _tecla(KEY_Q):
		ciclo = -1
	if ciclo != 0 and _ciclo_antes == 0:
		trocar_selecao(ciclo)
	_ciclo_antes = ciclo

	# Atirar (mouse esq / J / gatilho direito). A cadência limita o ritmo;
	# [decisão noturna 2026-06-18] o tiro sai na direção que o personagem encara (mira por
	# movimento). Mira livre por mouse/stick fica pra uma fatia futura.
	var atirar_p := _mouse(MOUSE_BUTTON_LEFT) or _tecla(KEY_J) \
		or _eixo(JOY_AXIS_TRIGGER_RIGHT) > 0.5
	if atirar_p:
		atirar()

	# Soco corpo a corpo (K / botão Y). O cooldown limita; derruba quem acertar.
	if _tecla(KEY_K) or _botao(JOY_BUTTON_Y):
		socar()

	# Unit/Plasma (segurar U / gatilho esquerdo): carrega e dispara ao completar. Soltar
	# antes do fim cancela. Só funciona com a Unit no estoque (item da Vault).
	var unit_p := _tecla(KEY_U) or _eixo(JOY_AXIS_TRIGGER_LEFT) > 0.5
	if unit_p:
		iniciar_carga_unit()
	elif esta_carregando_unit():
		_cancelar_carga()


## Troca a armadilha selecionada (passo +1/-1 na ORDEM).
func trocar_selecao(passo: int) -> void:
	var i := ORDEM.find(selecao)
	i = (i + passo + ORDEM.size()) % ORDEM.size()
	selecao = ORDEM[i]
	selecao_mudou.emit(selecao)


## Seleciona a armadilha pelo índice na ORDEM (usado pelo menu radial e por testes).
func selecionar_idx(i: int) -> void:
	i = ((i % ORDEM.size()) + ORDEM.size()) % ORDEM.size()
	selecao = ORDEM[i]
	selecao_mudou.emit(selecao)


# ───────────────────────── Menu radial de seleção (GDD 6.4) ─────────────────────────

func radial_aberto() -> bool:
	return _radial_aberto


func radial_idx() -> int:
	return _radial_idx


## Mapeia uma direção (x dir., y p/ baixo) na fatia da roda. Índice 0 no topo, horário.
func _dir_para_idx(dir: Vector2) -> int:
	var passo := TAU / float(ORDEM.size())
	var ang := atan2(dir.y, dir.x) + PI / 2.0   # topo (-90°) vira 0
	var i := int(round(ang / passo))
	return ((i % ORDEM.size()) + ORDEM.size()) % ORDEM.size()


## Segurar Tab (teclado) / R1 (gamepad) abre a roda; o direcional escolhe a fatia;
## soltar confirma a seleção (GDD 6.4). Q/E continua valendo como atalho rápido.
func _ler_radial() -> void:
	var aberto := _tecla(KEY_TAB) or _botao(JOY_BUTTON_RIGHT_SHOULDER)
	if aberto:
		if not _radial_aberto:
			_radial_aberto = true
			_radial_idx = ORDEM.find(selecao)  # começa na atual
		var dir := _obter_direcao()
		if dir.length() > 0.5:                  # só muda com o direcional firme
			_radial_idx = _dir_para_idx(dir)
	elif _radial_aberto:
		_radial_aberto = false
		selecionar_idx(_radial_idx)             # soltou: confirma a fatia


## Planta a armadilha do tipo dado (ou a selecionada). Faz snap no tile. Retorna true.
func plantar(tipo: String = "") -> bool:
	if tipo == "":
		tipo = selecao
	if int(inventario.get(tipo, 0)) <= 0:
		return false
	var coord := GridManager.world_to_grid(global_position)
	if not GridManager.pode_plantar(coord):
		return false
	var a := CENA_ARMADILHA.instantiate()
	a.stats = STATS[tipo]
	a.dono_id = id_jogador
	a.coord_grid = coord
	a.direcao_plantio = -global_transform.basis.z  # frente atual (pro Painel)
	get_parent().add_child(a)
	a.global_position = GridManager.grid_to_world(coord)
	GridManager.registrar_armadilha(coord, id_jogador, tipo, a)
	a.consumida.connect(_ao_armadilha_consumida.bind(tipo))
	AudioManager.tocar("plantar")
	inventario[tipo] = int(inventario[tipo]) - 1
	inventario_mudou.emit(tipo, inventario[tipo], STATS[tipo].inventario_inicial)
	return true


## Aciona todos os Detonadores armados deste jogador (botão de detonar).
func acionar_detonadores() -> void:
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a):
			continue
		if a.dono_id == id_jogador and a.stats.tipo == "detonador" and a.has_method("acionar"):
			a.acionar()


## Recarrega 1 unidade do tipo após o tempo de retorno (GDD). Capa no teto do loadout.
func _ao_armadilha_consumida(tipo: String) -> void:
	await get_tree().create_timer(STATS[tipo].tempo_retorno).timeout
	var teto := int(inventario_max.get(tipo, 0))
	inventario[tipo] = mini(int(inventario[tipo]) + 1, teto)
	inventario_mudou.emit(tipo, inventario[tipo], teto)


# ───────────────────────────── Caution Mode (GDD 6.1) ─────────────────────────────

## Raio do Caution Mode em unidades de mundo.
func raio_caution() -> float:
	return ALCANCE_CAUTION_TILES * GridManager.TAMANHO_TILE


func caution_ativo() -> bool:
	return _caution_ativo


## Liga/desliga manualmente (input em jogo; setter direto nos testes/IA).
func ativar_caution(v: bool) -> void:
	if v == _caution_ativo:
		return
	_caution_ativo = v
	caution_mudou.emit(_caution_ativo)


## Coords das armadilhas inimigas reveladas agora (vazio fora do Caution Mode).
func armadilhas_detectadas() -> Array[Vector2i]:
	if not _caution_ativo:
		return []
	return GridManager.armadilhas_inimigas_no_raio(id_jogador, global_position, raio_caution())


## Lê o botão de Caution (segurar C / L1). Estado contínuo, não por borda — anda segurando.
func _ler_caution() -> void:
	ativar_caution(_tecla(KEY_C) or _botao(JOY_BUTTON_LEFT_SHOULDER))


## Monta os pools de malhas do overlay uma vez (highlights de tile + marcadores), ocultos.
## Ficam no PAI (mundo), não como filhos do player, pra não girar/transladar com a cápsula.
func _construir_overlay_caution() -> void:
	_caution_no = Node3D.new()
	_caution_no.name = "OverlayCaution"
	# Filho do player, mas top_level: vive em espaço de MUNDO (não gira/transla com a
	# cápsula). Anexar a si mesmo evita o "parent busy" de mexer no pai durante o _ready.
	_caution_no.top_level = true
	add_child(_caution_no)

	# Pool de destaques de tile (azul translúcido, deitado no chão).
	var lado := GridManager.TAMANHO_TILE * 0.92
	var mat_tile := StandardMaterial3D.new()
	mat_tile.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_tile.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_tile.albedo_color = Color(0.1, 0.55, 1.0, 0.22)
	mat_tile.emission_enabled = true
	mat_tile.emission = Color(0.1, 0.55, 1.0)
	mat_tile.emission_energy_multiplier = 0.3
	for _i in range(25):  # 5x5 = teto de tiles no raio de 2
		var plano := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(lado, lado)
		plano.mesh = pm
		plano.material_override = mat_tile
		plano.visible = false
		_caution_no.add_child(plano)
		_caution_tiles.append(plano)

	# Pool de marcadores de armadilha detectada (amarelo, flutuando acima — GDD seção 12).
	var mat_marca := StandardMaterial3D.new()
	mat_marca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_marca.albedo_color = Color(1.0, 0.85, 0.1)
	mat_marca.emission_enabled = true
	mat_marca.emission = Color(1.0, 0.85, 0.1)
	mat_marca.emission_energy_multiplier = 2.0
	for _i in range(12):
		var marca := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.28
		sm.height = 0.56
		marca.mesh = sm
		marca.material_override = mat_marca
		marca.visible = false
		_caution_no.add_child(marca)
		_caution_marcas.append(marca)


## Mostra os tiles no alcance (azul) e um marcador sobre cada armadilha inimiga detectada.
func _atualizar_overlay_caution() -> void:
	if _caution_no == null:
		return
	if not _caution_ativo:
		if _caution_no.visible:
			_caution_no.visible = false
		return
	_caution_no.visible = true

	var centro := GridManager.world_to_grid(global_position)
	var raio := raio_caution()
	var alc := int(ceil(ALCANCE_CAUTION_TILES))
	var usados := 0
	for dx in range(-alc, alc + 1):
		for dy in range(-alc, alc + 1):
			if usados >= _caution_tiles.size():
				break
			var coord := centro + Vector2i(dx, dy)
			if not GridManager.dentro_do_grid(coord):
				continue
			var p := GridManager.grid_to_world(coord)
			if Vector2(p.x - global_position.x, p.z - global_position.z).length() > raio:
				continue
			var plano := _caution_tiles[usados]
			plano.global_position = Vector3(p.x, 0.05, p.z)  # acima das linhas do grid
			plano.visible = true
			usados += 1
	for i in range(usados, _caution_tiles.size()):
		_caution_tiles[i].visible = false

	# Marcadores sobre as armadilhas inimigas no alcance.
	var inimigas := GridManager.armadilhas_inimigas_no_raio(id_jogador, global_position, raio)
	var m := 0
	for coord in inimigas:
		if m >= _caution_marcas.size():
			break
		var p := GridManager.grid_to_world(coord)
		var marca := _caution_marcas[m]
		marca.global_position = Vector3(p.x, 1.4, p.z)
		marca.visible = true
		m += 1
	for i in range(m, _caution_marcas.size()):
		_caution_marcas[i].visible = false


# ─────────────────────── Desarme (GDD 6.2) e retomada (GDD 6.3) ───────────────────────

## Tomar dano durante o desarme detona a armadilha na hora (GDD 6.2), a menos que o
## Protect tenha barrado o golpe (aí o desarme continua).
func receber_dano(qtd: float, tipo_dano: String = "normal") -> void:
	var barrado := esta_protegido() and tipo_dano != "plasma"
	super.receber_dano(qtd, tipo_dano)
	if _desarme_alvo != null and not barrado:
		_falhar_desarme()


## Ganha uma armadilha de um tipo (item da Vault): +1 no inventário. Pode passar do
## loadout (item concede tipos que o personagem não tinha), elevando o teto.
func ganhar_armadilha(tipo: String) -> void:
	if not STATS.has(tipo):
		return
	var novo := int(inventario.get(tipo, 0)) + 1
	inventario_max[tipo] = maxi(int(inventario_max.get(tipo, 0)), novo)
	inventario[tipo] = novo
	inventario_mudou.emit(tipo, novo, int(inventario_max[tipo]))


func desarme_ativo() -> bool:
	return _desarme_alvo != null


## Snapshot pro HUD: sequência alvo, acertos, tempo restante e tamanho total.
func desarme_estado() -> Dictionary:
	return { "seq": _desarme_seq, "idx": _desarme_idx, "tempo": _desarme_tempo, "total": DESARME_TAM }


func retomada_disponivel() -> bool:
	return _retomada_alvo != null


## Encostar (em Caution Mode) em armadilha inimiga inicia o desarme; na própria, oferece
## retomar. Sem Caution Mode ou em cooldown, nada acontece (GDD 6.1/6.2/6.3).
func _ler_interacao() -> void:
	_retomada_alvo = null
	if not _caution_ativo or _desarme_cooldown > 0.0:
		_interagir_antes = _tecla(KEY_R)  # consome a borda
		return
	var inim := _armadilha_proxima(false)
	if inim != null:
		_iniciar_desarme(inim)  # encostou na inimiga: cancela o gatilho e abre o código
		return
	var propria := _armadilha_proxima(true)
	if propria != null:
		_retomada_alvo = propria
	var confirmar := _tecla(KEY_R) or _botao(JOY_BUTTON_X)
	if confirmar and not _interagir_antes and _retomada_alvo != null:
		_retomar(_retomada_alvo)
	_interagir_antes = confirmar


## Armadilha mais próxima (própria se `propria`, senão inimiga) até DIST_INTERACAO, ou null.
func _armadilha_proxima(propria: bool) -> Node:
	var melhor: Node = null
	var melhor_d := DIST_INTERACAO
	for a in get_tree().get_nodes_in_group("armadilhas"):
		if not is_instance_valid(a):
			continue
		if (int(a.dono_id) == id_jogador) != propria:
			continue
		var d := global_position.distance_to(a.global_position)
		if d <= melhor_d:
			melhor_d = d
			melhor = a
	return melhor


## Começa o desarme: cancela o gatilho e sorteia o Disarming Code (GDD 6.2).
func _iniciar_desarme(a: Node) -> void:
	a.cancelar_gatilho()
	_desarme_alvo = a
	_desarme_idx = 0
	_desarme_tempo = DESARME_TEMPO
	_desarme_seq.clear()
	for _i in range(DESARME_TAM):
		_desarme_seq.append(randi() % 4)
	desarme_iniciado.emit(_desarme_seq.duplicate(), _desarme_tempo)


## A cada frame em desarme: conta o tempo (zera = falha) e lê uma seta do código.
func _processar_desarme(delta: float) -> void:
	if not is_instance_valid(_desarme_alvo):
		_encerrar_desarme(false)  # armadilha sumiu por fora: aborta limpo
		return
	_desarme_tempo -= delta
	if _desarme_tempo <= 0.0:
		_falhar_desarme()
		return
	var d := _ler_direcao_codigo()
	if d >= 0:
		inserir_botao(d)


## Lê UMA seta por borda (setas do teclado / D-pad). -1 = nada novo apertado.
func _ler_direcao_codigo() -> int:
	var d := -1
	if _tecla(KEY_UP) or _botao(JOY_BUTTON_DPAD_UP):
		d = 0
	elif _tecla(KEY_DOWN) or _botao(JOY_BUTTON_DPAD_DOWN):
		d = 1
	elif _tecla(KEY_LEFT) or _botao(JOY_BUTTON_DPAD_LEFT):
		d = 2
	elif _tecla(KEY_RIGHT) or _botao(JOY_BUTTON_DPAD_RIGHT):
		d = 3
	var saida := d if d != _codigo_antes else -1
	_codigo_antes = d
	return saida


## Processa um botão do código (público pra teste/IA). Acerto avança; erro falha (GDD 6.2).
func inserir_botao(dir: int) -> void:
	if _desarme_alvo == null:
		return
	if dir == _desarme_seq[_desarme_idx]:
		_desarme_idx += 1
		if _desarme_idx >= _desarme_seq.size():
			_concluir_desarme()
	else:
		_falhar_desarme()


## Sucesso: armadilha some sem explodir; o inimigo a perde e o Healer sobe um pouco.
## Limpa o estado ANTES de mexer na armadilha (evita reentrância pelos sinais).
func _concluir_desarme() -> void:
	var alvo := _desarme_alvo
	AudioManager.tocar("desarme")
	curar(DESARME_CURA)
	_encerrar_desarme(true)
	if is_instance_valid(alvo):
		alvo.remover_por_desarme()


## Falha: a armadilha reage (explode ou re-arma) e o desarme acaba. Limpa o estado
## ANTES da reação — a explosão volta dano pra cá via receber_dano e não pode recorrer.
func _falhar_desarme() -> void:
	var alvo := _desarme_alvo
	_encerrar_desarme(false)
	if is_instance_valid(alvo):
		alvo.reagir_falha_desarme()


func _encerrar_desarme(sucesso: bool) -> void:
	_desarme_alvo = null
	_desarme_seq.clear()
	_desarme_idx = 0
	_desarme_cooldown = DESARME_COOLDOWN
	_codigo_antes = -1
	desarme_encerrado.emit(sucesso)


## Retomada (GDD 6.3): recolhe a própria armadilha e devolve +1 ao inventário na hora.
func _retomar(a: Node) -> void:
	var tipo := String(a.stats.tipo)
	a.recolher()
	var teto := int(inventario_max.get(tipo, 0))
	inventario[tipo] = mini(int(inventario.get(tipo, 0)) + 1, teto)
	inventario_mudou.emit(tipo, inventario[tipo], teto)
	_retomada_alvo = null
	_desarme_cooldown = DESARME_COOLDOWN
