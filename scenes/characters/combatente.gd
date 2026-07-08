extends CharacterBody3D
## Combatente — base comum de Player e Bot.
##
## Concentra o que os dois compartilham: o Healer (vida, GDD seção 7.3), receber
## dano, knockback e o registro no grupo "combatentes" (usado pela Mina pra achar
## alvos sem acoplamento forte). Quem herda chama super._ready().
class_name Combatente

## Emitido quando o Healer muda (a HUD ouve — comunicação por signal).
signal healer_mudou(atual: float, maximo: float)
## Emitido quando o Healer chega a zero (fim de partida desse combatente).
signal healer_zerou
## Emitido quando a munição muda (a HUD ouve).
signal municao_mudou(atual: int, maximo: int)

const HEALER_MAX: float = 100.0
const ALTURA_PISO: float = 1.0  # centro da cápsula p/ os pés ficarem no chão (y=0)
const GRAVIDADE: float = 22.0   # usada só nos mapas verticais (gravidade_ativa)

## Mapas planos travam a altura (rápido, simples). Mapas com rampa/ponte ligam a
## gravidade: o personagem segue o chão de colisão (sobe rampa, anda sobre a ponte).
@export var gravidade_ativa: bool = false

# Arma de projétil (GDD 7.1). Valores base usados quando não há StatsPersonagem.
const MUNICAO_MAX: int = 6
const RECARGA_TEMPO: float = 1.5    # s recarregando (vulnerável: não atira)
const CADENCIA: float = 0.28        # s entre tiros
const TIRO_DANO: float = 12.0
const TIRO_RAPIDEZ: float = 22.0    # m/s do projétil
const PROJETIL := preload("res://scenes/projeteis/projetil.tscn")

## Specs das 6 armas do roster (GDD seção 4, derivado do FAQ do Trap Gunner).
## A chave é o campo `arma` do StatsPersonagem (.tres). Cada arma tem identidade:
##  - pistola (Brecht): equilibrada;      - shotgun (Magnus): leque curto e forte;
##  - handgun (Vesna): metralha fraca;    - missil (Pip): teleguiado, DERRUBA, lento;
##  - laminas (Kestrel): rápidas/fracas;  - soco_foguete (Mara): teleguiado curto, DERRUBA.
const ARMAS := {
	"pistola": {"dano": 12.0, "cadencia": 0.30, "rapidez": 22.0, "pellets": 1,
		"abertura": 0.0, "teleguiada": false, "derruba": false, "vida": 2.0,
		"cor": Color(1.0, 0.85, 0.3)},
	"shotgun": {"dano": 7.0, "cadencia": 0.95, "rapidez": 20.0, "pellets": 5,
		"abertura": 26.0, "teleguiada": false, "derruba": false, "vida": 0.55,
		"cor": Color(1.0, 0.55, 0.2)},
	"handgun": {"dano": 9.0, "cadencia": 0.16, "rapidez": 24.0, "pellets": 1,
		"abertura": 0.0, "teleguiada": false, "derruba": false, "vida": 1.8,
		"cor": Color(0.4, 0.9, 1.0)},
	"missil": {"dano": 11.0, "cadencia": 1.1, "rapidez": 9.5, "pellets": 1,
		"abertura": 0.0, "teleguiada": true, "derruba": true, "vida": 4.5,
		"cor": Color(1.0, 0.4, 0.25)},
	"laminas": {"dano": 6.0, "cadencia": 0.14, "rapidez": 26.0, "pellets": 1,
		"abertura": 0.0, "teleguiada": false, "derruba": false, "vida": 1.6,
		"cor": Color(0.5, 1.0, 0.8)},
	"soco_foguete": {"dano": 10.0, "cadencia": 1.0, "rapidez": 8.0, "pellets": 1,
		"abertura": 0.0, "teleguiada": true, "derruba": true, "vida": 3.5,
		"cor": Color(1.0, 0.35, 0.9)},
}

## Preload (não o class_name global) pra resolver o tipo em headless — mesmo truque do
## StatsArmadilha (ver memória godot-mcp-lib-quirks).
const StatsPersonagem := preload("res://scripts/stats_personagem.gd")

## Identidade de time. 1 = jogador, 2 = bot. A Mina usa isto pra saber quem é inimigo.
@export var id_jogador: int = 1
## Stats do personagem (.tres, Fase 5). Se nulo, usa os valores-base abaixo.
@export var stats: StatsPersonagem = null

# Valores efetivos (preenchidos do stats no _ready, ou caem nos defaults-base).
var vida_max: float = HEALER_MAX
var municao_max: int = MUNICAO_MAX
var velocidade_base: float = 7.0

var healer: float = HEALER_MAX
var municao: int = MUNICAO_MAX

# Efeitos de status das armadilhas (Cova/Gás — bloco 2 da Fase 3).
var _imobilizado_restante: float = 0.0   # segundos sem poder andar (Cova/Gás)
var _slow_restante: float = 0.0          # segundos com velocidade reduzida (Gás)
var _slow_fator: float = 1.0             # multiplicador de velocidade enquanto no slow

# Itens da Vault (GDD 8): Speed Up e Protect.
var _speed_restante: float = 0.0         # segundos com velocidade aumentada
var _speed_fator: float = 1.0            # multiplicador (2.0 = dobro)
var _protegido_restante: float = 0.0     # invencível (menos contra a Plasma)

# Arma: timers de cadência e recarga.
var _cadencia_restante: float = 0.0
var _recarga_restante: float = 0.0

# Knockback por IMPULSO físico (não teleporte). O empurrão vira uma velocidade extra
# que decai exponencialmente — o corpo DESLIZA com peso em vez de saltar de posição
# (e respeita colisão, já que entra no move_and_slide das subclasses). A distância
# total percorrida ≈ `forca` (integral de v0·e^(-λt) com v0 = forca·λ).
const IMPULSO_FREIO: float = 8.0     # λ do decaimento (1/s) — alto = arcade, seco
var _impulso: Vector3 = Vector3.ZERO

# Corpo a corpo (GDD 7.2): soco de curto alcance que DERRUBA. Derrubado = sem controle.
const SOCO_ALCANCE: float = 1.9
const SOCO_DANO: float = 10.0
const SOCO_COOLDOWN: float = 0.6
const DERRUBADO_TEMPO: float = 0.9
const DERRUBADO_EMPURRAO: float = 3.0
var _soco_cd: float = 0.0
var _derrubado_restante: float = 0.0

# Unit (Plasma), o super (GDD 9). Conquistado por item da Vault. Carrega e dispara
# uma Plasma teleguiada; quebra se o dono for derrubado durante a carga.
const UNIT_CARGA: float = 1.8       # s segurando pra completar a carga
const UNIT_DANO: float = 40.0
const PLASMA := preload("res://scenes/projeteis/plasma.tscn")
## Emitido quando a posse/quantidade da Unit muda (HUD).
signal unit_mudou(tem: bool, bombs: int)
var tem_unit: bool = false
var plasma_bombs: int = 0
var _carregando_unit: bool = false
var _carga_restante: float = 0.0


func _ready() -> void:
	add_to_group("combatentes")
	position.y = ALTURA_PISO
	aplicar_stats()
	_montar_modelo()
	healer = vida_max
	municao = municao_max
	healer_mudou.emit(healer, vida_max)
	municao_mudou.emit(municao, municao_max)


## Modelo fallback (sem StatsPersonagem): Quaternius SWAT tingido pela cor do time —
## MESMA família visual do roster (Modular Men/Women, proporções humanas, CC0).
const MODELO_PADRAO_PATH := "res://assets/models/quaternius/swat.gltf"
## Altura-alvo do personagem em mundo (~1 tile de largura de ombros). O modelo padrão é
## auto-ajustado pra esta altura pelo AABB — 6.5 fixo deixava o boneco com 2+ tiles.
const ALTURA_MODELO_ALVO := 2.5
const OFFSET_PADRAO := -1.0

## Troca a cápsula pelo modelo 3D. Usa o modelo do personagem (StatsPersonagem) se houver;
## senão, em jogo real (não nos testes), cai no modelo padrão. Adiciona o anel do time.
## Idempotente: pode ser chamado de novo ao trocar de personagem em runtime.
func _montar_modelo() -> void:
	var antigo := get_node_or_null("Modelo")
	if antigo != null:
		antigo.queue_free()
	var malha := get_node_or_null("Malha")
	var cena: PackedScene = null
	var escala := 0.0               # 0 = auto-ajustar pela AABB (modelo padrão)
	var rot := 0.0
	var offset := OFFSET_PADRAO
	if stats != null and stats.cena_modelo != null:
		cena = stats.cena_modelo
		escala = stats.escala_modelo
		rot = stats.rotacao_modelo_y
		offset = stats.offset_modelo_y
	elif not _modo_teste() and ResourceLoader.exists(MODELO_PADRAO_PATH):
		cena = load(MODELO_PADRAO_PATH)
	if cena == null:
		if malha != null:
			malha.visible = true   # sem modelo: mostra a cápsula placeholder
		_remover_anel_time()
		return
	if malha != null:
		malha.visible = false      # com modelo: esconde a cápsula
	var m: Node3D = cena.instantiate()
	m.name = "Modelo"
	add_child(m)
	if escala <= 0.0:
		# Auto-fit: mede a AABB crua do modelo e escala pra altura-alvo do personagem
		# (por arquétipo — tanque avulta, assassina é miúda) ou o padrão.
		var alvo_alt := ALTURA_MODELO_ALVO
		if stats != null and stats.get("altura_modelo") != null and float(stats.altura_modelo) > 0.1:
			alvo_alt = float(stats.altura_modelo)
		var alt := _altura_aabb(m)
		escala = (alvo_alt / alt) if alt > 0.01 else 1.0
	m.scale = Vector3.ONE * escala
	m.rotation.y = deg_to_rad(rot)
	m.position.y = offset           # pivot nos pés -> desce pro chão
	# Tinta de time SÓ no modelo fallback (os dois usariam o mesmo boneco).
	if stats == null or stats.cena_modelo == null:
		_tingir_modelo(m)
	else:
		# RECOLOR TÁTICO (Briefing §1.1): civil vira operador — roupa escura
		# dessaturada, pele intacta, e a peça mais chamativa vira acento EMISSIVO
		# na cor do TIME (o duelo azul×vermelho é a assinatura do jogo).
		recolorir_tatico(m, Color(0.35, 0.7, 1.0) if id_jogador == 1 else Color(1.0, 0.35, 0.35))
	_aplicar_rim_time(m)
	_configurar_animacao(m)
	_montar_arma_visual(m)
	_montar_anel_time()


## Rim light fresnel na cor do TIME por cima do material original (overlay — não
## repinta a textura KayKit). Personagem legível sobre chão escuro + leitura de lado.
func _aplicar_rim_time(m: Node3D) -> void:
	var shader := load("res://assets/shaders/rim_time.gdshader") as Shader
	if shader == null:
		return
	var cor := Color(0.35, 0.7, 1.0) if id_jogador == 1 else Color(1.0, 0.35, 0.35)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("cor", cor)
	for filho in m.find_children("*", "MeshInstance3D", true, false):
		(filho as MeshInstance3D).material_overlay = mat


## Modelo 3D da ARMA do personagem (Quaternius CC0 em assets/models/armas/<arma>.fbx),
## preso ao OSSO DA MÃO direita (BoneAttachment3D em Wrist.R) — antes ficava pendurado
## no corpo na altura do quadril e lia como "faca amarrada na coxa" (bug do playtest).
## Sem esqueleto/osso, cai no ponto fixo antigo. Sem arquivo pro tipo, mão livre.
func _montar_arma_visual(m: Node3D = null) -> void:
	var antigo := get_node_or_null("ArmaVisual")
	if antigo != null:
		antigo.queue_free()
	if stats == null:
		return
	var caminho := "res://assets/models/armas/%s.fbx" % stats.arma
	if not ResourceLoader.exists(caminho):
		return
	var cena: PackedScene = load(caminho)
	if cena == null:
		return
	var arma: Node3D = cena.instantiate()
	# Procura o esqueleto do modelo e o osso da mão direita (família Quaternius: Wrist.R).
	var skel: Skeleton3D = null
	if m != null:
		var achados := m.find_children("*", "Skeleton3D", true, false)
		if not achados.is_empty():
			skel = achados[0]
	var osso := -1
	if skel != null:
		for nome_osso in ["Wrist.R", "Hand.R", "hand.R"]:
			osso = skel.find_bone(nome_osso)
			if osso >= 0:
				break
	if skel != null and osso >= 0:
		var ba := BoneAttachment3D.new()
		ba.name = "ArmaNaMao"
		ba.bone_name = skel.get_bone_name(osso)
		skel.add_child(ba)
		arma.name = "Arma"
		ba.add_child(arma)
		# Auto-escala em ESPAÇO DE MUNDO (compensa o ×100 dos FBX e a escala do modelo).
		var dim := _maior_dim_aabb_mundo(arma)
		if dim > 0.001:
			arma.scale = arma.scale * (0.62 / dim)   # ~0.62u de cano na mão
		# Empunhadura: cabo dentro da palma, cano pra frente do personagem.
		arma.position = Vector3(0.0, 0.07, 0.03)
		arma.rotation_degrees = Vector3(0.0, 180.0, 90.0)
	else:
		# Fallback sem rig: ponto fixo ao lado direito (comportamento antigo).
		arma.name = "ArmaVisual"
		add_child(arma)
		var dim2 := _maior_dim_aabb_mundo(arma)
		if dim2 > 0.001:
			arma.scale = arma.scale * (0.85 / dim2)
		arma.position = Vector3(0.42, 0.1, -0.25)
		arma.rotation.y = PI


## Maior dimensão (X/Y/Z) das malhas em espaço de MUNDO (precisa estar na árvore).
func _maior_dim_aabb_mundo(no: Node3D) -> float:
	var maior := 0.0
	for filho in no.find_children("*", "MeshInstance3D", true, false):
		var mi := filho as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		maior = maxf(maior, maxf(ab.size.x, maxf(ab.size.y, ab.size.z)))
	return maior


# ─────────────── Animação do modelo (idle / correr / derrubado) ───────────────

var _anim: AnimationPlayer = null
var _anim_idle: String = ""
var _anim_mover: String = ""
var _anim_derrubado: String = ""
var _anim_morte: String = ""
var _anim_vitoria: String = ""
var _anim_atirar: String = ""
var _anim_plantar: String = ""
var _anim_soco: String = ""
var _anim_atual: String = ""
var _comemorar_ate_ms: int = 0   # comemora (fim de round) até este tick
var _acao_ate_ms: int = 0        # animação de AÇÃO (tiro/plantio/soco) até este tick
var _anim_acao: String = ""


## Acha o AnimationPlayer do modelo e resolve os nomes das animações (KayKit ou
## qualquer glb: procura por nome exato e cai pra substring, ex. "Rig|Idle").
func _configurar_animacao(m: Node3D) -> void:
	_anim = null
	_anim_atual = ""
	var achados := m.find_children("*", "AnimationPlayer", true, false)
	if achados.is_empty():
		return
	_anim = achados[0]
	# Nomes da Universal Animation Library primeiro (postura de pistola = a cara de
	# "gunner"); nomes Modular/KayKit como fallback pra qualquer glb futuro.
	_anim_idle = _primeira_anim(["Pistol_Idle_Loop", "Idle_Gun", "Idle_Loop", "Idle"])
	_anim_mover = _primeira_anim(["Jog_Fwd_Loop", "Sprint_Loop", "Run", "Walk_Loop", "Walk"])
	_anim_derrubado = _primeira_anim(["Hit_Chest", "HitRecieve", "Hit_A", "Hit_B"])
	_anim_morte = _primeira_anim(["Death01", "Death", "Death_A"])
	_anim_vitoria = _primeira_anim(["Dance_Loop", "Wave", "Cheer", "Victory"])
	# Ações de combate:
	_anim_atirar = _primeira_anim(["Pistol_Shoot", "Idle_Gun_Shoot", "Gun_Shoot", "Shoot"])
	_anim_plantar = _primeira_anim(["Interact", "PickUp_Table", "Use_Item", "PickUp"])
	_anim_soco = _primeira_anim(["Punch_Cross", "Punch_Jab", "Punch_Right", "Punch"])
	# Idle e corrida precisam de LOOP (glb nem sempre traz a flag).
	for nome in [_anim_idle, _anim_mover]:
		if nome != "":
			var a := _anim.get_animation(nome)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR


func _primeira_anim(nomes: Array) -> String:
	for n in nomes:
		if _anim.has_animation(n):
			return String(n)
	for completa in _anim.get_animation_list():
		for n in nomes:
			if String(completa).to_lower().contains(String(n).to_lower()):
				return String(completa)
	return ""


## Comemora (fim de round vencido — a arena chama) por `dur` segundos.
func comemorar(dur: float = 2.0) -> void:
	_comemorar_ate_ms = Time.get_ticks_msec() + int(dur * 1000.0)


## Troca a animação conforme o estado (chamado no _process). O corpo SE MOVE junto
## com o movimento — pedido do playtest. Prioridade: morte > vitória > knockdown >
## correr > idle.
func _atualizar_animacao() -> void:
	if _anim == null or not is_instance_valid(_anim):
		return
	var alvo := _anim_idle
	if healer <= 0.0:
		alvo = _anim_morte
	elif Time.get_ticks_msec() < _comemorar_ate_ms:
		alvo = _anim_vitoria
	elif esta_derrubado():
		alvo = _anim_derrubado
	elif Time.get_ticks_msec() < _acao_ate_ms and _anim_acao != "":
		alvo = _anim_acao   # tiro/plantio/soco: gesto curto por cima do idle/corrida
	elif Vector2(velocity.x, velocity.z).length() > 0.8:
		alvo = _anim_mover
	if alvo != "" and alvo != _anim_atual:
		_anim_atual = alvo
		_anim.play(alvo, 0.2)


## Toca uma animação de AÇÃO curta (tiro, plantio, soco) por cima do estado atual.
func _tocar_acao(nome: String, dur: float) -> void:
	if nome == "" or _anim == null or not is_instance_valid(_anim):
		return
	_anim_acao = nome
	_acao_ate_ms = Time.get_ticks_msec() + int(dur * 1000.0)
	_anim_atual = nome
	_anim.play(nome, 0.1)


## Gesto público de plantio (player e bot chamam ao plantar armadilha).
func animar_plantio() -> void:
	_tocar_acao(_anim_plantar, 0.45)


## Altura combinada (eixo Y) das malhas de um modelo, no espaço local dele.
func _altura_aabb(no: Node) -> float:
	var minimo := 1.0e9
	var maximo := -1.0e9
	for filho in no.find_children("*", "MeshInstance3D", true, false):
		var mi := filho as MeshInstance3D
		if mi.mesh == null:
			continue
		var ab := mi.get_aabb()
		minimo = minf(minimo, ab.position.y)
		maximo = maxf(maximo, ab.position.y + ab.size.y)
	return maxf(0.0, maximo - minimo)


## Recolor TÁTICO por superfície (estático: os retratos usam também). Escurece e
## dessatura as roupas (ambiente ≤35% — Art Bible), PRESERVA a pele, e transforma a
## superfície mais saturada do modelo em acento emissivo na cor dada.
static func recolorir_tatico(m: Node3D, cor_acento: Color) -> void:
	var melhor_mi: MeshInstance3D = null
	var melhor_si := -1
	var melhor_sat := -1.0
	for filho in m.find_children("*", "MeshInstance3D", true, false):
		var mi := filho as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(si) as StandardMaterial3D
			if mat == null:
				continue
			var c := mat.albedo_color
			# Pele/rosto: matiz quente, claro, pouco saturado — não tocar.
			if c.h > 0.01 and c.h < 0.13 and c.v > 0.55 and c.s < 0.55:
				continue
			var novo := mat.duplicate() as StandardMaterial3D
			novo.albedo_color = Color.from_hsv(c.h, minf(c.s * 0.4, 0.3), c.v * 0.6)
			mi.set_surface_override_material(si, novo)
			if c.s * c.v > melhor_sat:   # a peça mais VIVA do civil vira o LED do operador
				melhor_sat = c.s * c.v
				melhor_mi = mi
				melhor_si = si
	if melhor_mi != null and melhor_si >= 0 and melhor_sat > 0.08:
		# Só vira LED se a peça era de fato VIVA — num manequim cinza (tudo s≈0)
		# o "acento" seria o corpo inteiro brilhando.
		var acento := melhor_mi.get_surface_override_material(melhor_si) as StandardMaterial3D
		if acento != null:
			acento.albedo_color = Color(cor_acento.r * 0.45, cor_acento.g * 0.45, cor_acento.b * 0.45)
			acento.emission_enabled = true
			acento.emission = cor_acento
			acento.emission_energy_multiplier = 1.1
	elif melhor_sat <= 0.08:
		# Manequim/monocromático: TINTA pessoal escura no corpo inteiro (uniforme de
		# operador na cor do personagem) — a identidade vem do matiz.
		for filho in m.find_children("*", "MeshInstance3D", true, false):
			var mi2 := filho as MeshInstance3D
			if mi2.mesh == null:
				continue
			for si2 in mi2.mesh.get_surface_count():
				var so := mi2.get_surface_override_material(si2) as StandardMaterial3D
				if so != null:
					so.albedo_color = Color.from_hsv(cor_acento.h, 0.35, 0.32)


## Pinta o modelo inteiro com a cor do time (material chapado): P1 azul, P2 vermelho.
## Resolve o print do playtest onde os DOIS eram o mesmo boneco amarelo.
func _tingir_modelo(m: Node3D) -> void:
	var cor := _cor_time()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor.lerp(Color.WHITE, 0.25)
	mat.roughness = 0.7
	mat.metallic = 0.05
	for filho in m.find_children("*", "MeshInstance3D", true, false):
		(filho as MeshInstance3D).material_override = mat


func _modo_teste() -> bool:
	return "--teste" in OS.get_cmdline_user_args()


## Anel luminoso no chão na cor do time — distingue player/bot na visão top-down.
func _montar_anel_time() -> void:
	_remover_anel_time()
	var mi := MeshInstance3D.new()
	mi.name = "AnelTime"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.62
	mi.mesh = torus
	# Anel SEMPRE na cor do TIME (P1 azul, P2 vermelho) — igual às barras da HUD.
	# A cor do personagem (stats.cor_time) fica pra UI de seleção, não pra leitura de lado.
	var cor := Color(0.3, 0.7, 1.0) if id_jogador == 1 else Color(1.0, 0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	add_child(mi)
	mi.position.y = -ALTURA_PISO + 0.06   # rente ao chão


func _remover_anel_time() -> void:
	var a := get_node_or_null("AnelTime")
	if a != null:
		a.queue_free()


## Cor do time: a do personagem, ou um padrão por id (player azul, bot vermelho).
func _cor_time() -> Color:
	if stats != null and stats.cor_time != null:
		return stats.cor_time
	return Color(0.3, 0.7, 1.0) if id_jogador == 1 else Color(1.0, 0.3, 0.3)


## Lê o StatsPersonagem (se houver) pros valores efetivos. Subclasses sobrescrevem o
## default de velocidade quando não há stats (player 7, bot 5).
func aplicar_stats() -> void:
	if stats != null:
		vida_max = stats.vida_max
		municao_max = stats.municao_max
		velocidade_base = stats.velocidade


## Troca o personagem em runtime (escolha da tela de seleção): reaplica os valores e
## reseta vida/munição. Subclasses estendem (o player refaz o inventário do loadout).
func aplicar_personagem(novo: Resource) -> void:
	stats = novo
	aplicar_stats()
	_montar_modelo()
	healer = vida_max
	municao = municao_max
	healer_mudou.emit(healer, vida_max)
	municao_mudou.emit(municao, municao_max)


## Decai os timers de status e da arma. Roda na base (subclasses só fazem _physics_process).
func _process(delta: float) -> void:
	if _imobilizado_restante > 0.0:
		_imobilizado_restante = maxf(0.0, _imobilizado_restante - delta)
	if _slow_restante > 0.0:
		_slow_restante = maxf(0.0, _slow_restante - delta)
	if _speed_restante > 0.0:
		_speed_restante = maxf(0.0, _speed_restante - delta)
	if _protegido_restante > 0.0:
		_protegido_restante = maxf(0.0, _protegido_restante - delta)
	if _cadencia_restante > 0.0:
		_cadencia_restante = maxf(0.0, _cadencia_restante - delta)
	if _recarga_restante > 0.0:
		_recarga_restante = maxf(0.0, _recarga_restante - delta)
		if _recarga_restante == 0.0:        # recarga terminou: pente cheio
			municao = municao_max
			municao_mudou.emit(municao, municao_max)
	if _soco_cd > 0.0:
		_soco_cd = maxf(0.0, _soco_cd - delta)
	if _derrubado_restante > 0.0:
		_derrubado_restante = maxf(0.0, _derrubado_restante - delta)
	if _impulso != Vector3.ZERO:
		_impulso *= exp(-IMPULSO_FREIO * delta)   # knockback decai (deslize com peso)
		if _impulso.length_squared() < 0.16:
			_impulso = Vector3.ZERO
	if _carregando_unit:
		_carga_restante = maxf(0.0, _carga_restante - delta)
		if _carga_restante == 0.0:
			_disparar_plasma()
	# Poeira + SOM de passos ao correr (vida no movimento).
	_t_poeira -= delta
	if _t_poeira <= 0.0 and not esta_derrubado() \
			and Vector2(velocity.x, velocity.z).length() > 3.0:
		_t_poeira = 0.22
		_fx_poeira()
		AudioManager.tocar("passos")
	_atualizar_animacao()


var _t_poeira: float = 0.0


## Baforada de poeira nos pés (dust dos passos). One-shot barato, autodestrói.
func _fx_poeira() -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.amount = 5
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 45.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.7
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	p.mesh = sm
	p.color = Color(0.7, 0.72, 0.78, 0.4)
	p.add_to_group("fx")
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, -0.8, 0.0)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


## True enquanto recarrega (não pode atirar — GDD 7.1, fica vulnerável).
func esta_recarregando() -> bool:
	return _recarga_restante > 0.0


func esta_derrubado() -> bool:
	return _derrubado_restante > 0.0


## Soco de curto alcance (GDD 7.2): acerta o inimigo mais próximo no alcance, dá dano e
## o DERRUBA. Bloqueado em cooldown, preso ou já derrubado.
func socar() -> void:
	if _soco_cd > 0.0 or _derrubado_restante > 0.0 or _imobilizado_restante > 0.0:
		return
	_soco_cd = SOCO_COOLDOWN
	_tocar_acao(_anim_soco, 0.4)   # o swing aparece mesmo errando (feedback honesto)
	var alvo := _inimigo_no_alcance(SOCO_ALCANCE)
	if alvo == null:
		return
	AudioManager.tocar("soco")
	alvo.receber_dano(SOCO_DANO)
	if alvo.has_method("derrubar"):
		alvo.derrubar(alvo.global_position - global_position, DERRUBADO_EMPURRAO)


## Sofre um knockdown: empurrão + tempo sem controle (GDD 7.2). Se estava carregando a
## Unit, o lançador QUEBRA (perde a Unit — GDD 7.2/9).
func derrubar(direcao: Vector3, forca: float) -> void:
	_derrubado_restante = DERRUBADO_TEMPO
	aplicar_empurrao(direcao, forca)
	AudioManager.tocar("derrubado")
	get_tree().call_group("camera", "tremer", 0.25)  # screenshake no knockdown (juice)
	GameManager.hit_stop(0.25, 0.04)                 # micro-pausa: o soco tem peso
	if _carregando_unit:
		tem_unit = false
		plasma_bombs = 0
		_cancelar_carga()
		unit_mudou.emit(tem_unit, plasma_bombs)


# ───────────────────────────── Unit / Plasma (GDD 9) ─────────────────────────────

## Concede a Unit (item da Vault). Soma Plasma Bombs.
func conceder_unit(qtd: int = 1) -> void:
	tem_unit = true
	plasma_bombs += qtd
	unit_mudou.emit(tem_unit, plasma_bombs)


func esta_carregando_unit() -> bool:
	return _carregando_unit


## Fração da carga (0..1) pra HUD; 0 quando não está carregando.
func carga_unit_frac() -> float:
	if not _carregando_unit:
		return 0.0
	return clampf(1.0 - _carga_restante / UNIT_CARGA, 0.0, 1.0)


## Começa a carregar a Plasma (segurar o botão). Bloqueado sem Unit, sem bomb, preso ou
## derrubado. Atacado durante a carga, ela é cancelada e não dispara (GDD 9).
func iniciar_carga_unit() -> void:
	if not tem_unit or plasma_bombs <= 0 or _carregando_unit:
		return
	if _derrubado_restante > 0.0 or _imobilizado_restante > 0.0:
		return
	_carregando_unit = true
	_carga_restante = UNIT_CARGA


func _cancelar_carga() -> void:
	if _carregando_unit:
		_carregando_unit = false
		_carga_restante = 0.0


## Carga completa: dispara a Plasma teleguiada no inimigo e gasta uma bomb.
func _disparar_plasma() -> void:
	_carregando_unit = false
	var dir := -global_transform.basis.z
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	var p := PLASMA.instantiate()
	p.dono_id = id_jogador
	p.dano = UNIT_DANO
	p.alvo = _inimigo_no_alcance(99999.0)
	get_parent().add_child(p)
	p.global_position = global_position + dir.normalized() * 1.3
	p.global_position.y = 1.0
	plasma_bombs -= 1
	unit_mudou.emit(tem_unit, plasma_bombs)


## Inimigo (outro time) mais próximo dentro de `raio`, ou null.
func _inimigo_no_alcance(raio: float) -> Node:
	var melhor: Node = null
	var melhor_d := raio
	for c in get_tree().get_nodes_in_group("combatentes"):
		if c == self or not is_instance_valid(c):
			continue
		if int(c.get("id_jogador")) == id_jogador:
			continue
		var d := global_position.distance_to(c.global_position)
		if d <= melhor_d:
			melhor_d = d
			melhor = c
	return melhor


## Dispara a ARMA do personagem na frente (-Z), se houver munição e cadência liberada.
## Cada arma tem specs próprias (ARMAS): leque de pellets (shotgun), teleguiada com
## knockdown (míssil/soco-foguete), cor/luz do projétil. Zerou a munição: recarrega.
func atirar() -> void:
	if _recarga_restante > 0.0 or _cadencia_restante > 0.0 or municao <= 0:
		return
	if _imobilizado_restante > 0.0 or _derrubado_restante > 0.0:
		return  # preso na Cova/Gás ou derrubado não atira
	var dir := -global_transform.basis.z
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	# Aim assist leve (mira por movimento precisa de ajuda): se o inimigo está num
	# cone de 30° na frente, o tiro sai NELE. Fora do cone, sai reto (dá pra errar).
	var assistido := _inimigo_no_alcance(20.0)
	if assistido != null:
		var para_inim: Vector3 = assistido.global_position - global_position
		para_inim.y = 0.0
		if para_inim.length() > 0.01 and dir.angle_to(para_inim.normalized()) <= deg_to_rad(30.0):
			dir = para_inim.normalized()
	var spec: Dictionary = {}
	if stats != null:
		spec = ARMAS.get(stats.arma, {})
	var pellets: int = int(spec.get("pellets", 1))
	var abertura := deg_to_rad(float(spec.get("abertura", 0.0)))
	for i in pellets:
		var ang := 0.0
		if pellets > 1:
			ang = lerpf(-abertura * 0.5, abertura * 0.5, float(i) / float(pellets - 1))
		var d := dir.rotated(Vector3.UP, ang)
		var p := PROJETIL.instantiate()
		p.dono_id = id_jogador
		p.dano = float(spec.get("dano", TIRO_DANO))
		p.velocidade = d * float(spec.get("rapidez", TIRO_RAPIDEZ))
		p.vida = float(spec.get("vida", 2.0))
		p.cor = spec.get("cor", Color(1.0, 0.9, 0.35))
		p.derruba = bool(spec.get("derruba", false))
		if bool(spec.get("teleguiada", false)):
			p.teleguiado = true
			p.alvo = _inimigo_no_alcance(99999.0)
		get_parent().add_child(p)
		p.global_position = global_position + d * 1.1
		p.global_position.y = 1.0
	municao -= 1
	_cadencia_restante = float(spec.get("cadencia", CADENCIA))
	AudioManager.tocar("tiro")
	_tocar_acao(_anim_atirar, 0.3)
	_fx_muzzle(global_position + dir * 1.1 + Vector3(0.0, 0.15, 0.0), spec.get("cor", Color(1.0, 0.9, 0.35)))
	municao_mudou.emit(municao, municao_max)
	if municao <= 0:
		_recarga_restante = RECARGA_TEMPO


## Clarão de saída do tiro: luz curtíssima + faíscas na boca do cano. O flash é o que
## faz o tiro "existir" — sem ele a arma parece um apontador.
func _fx_muzzle(pos: Vector3, cor: Color) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 3.0
	luz.omni_range = 4.0
	luz.shadow_enabled = false
	luz.add_to_group("fx")
	get_parent().add_child(luz)
	luz.global_position = pos
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.1)
	tw.tween_callback(luz.queue_free)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 8
	p.lifetime = 0.18
	p.direction = Vector3(0, 0, -1)
	p.spread = 25.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.1
	p.mesh = SphereMesh.new()
	(p.mesh as SphereMesh).radius = 0.5
	(p.mesh as SphereMesh).height = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 3.0
	p.mesh.surface_set_material(0, mat)
	p.add_to_group("fx")
	get_parent().add_child(p)
	p.global_position = pos
	p.rotation.y = rotation.y   # cone de faíscas na direção do tiro
	p.emitting = true
	p.finished.connect(p.queue_free)


## Trava o movimento por `duracao` segundos (Cova/Gás). Não encurta um efeito maior já ativo.
func imobilizar(duracao: float) -> void:
	_imobilizado_restante = maxf(_imobilizado_restante, duracao)


## Reduz a velocidade por `duracao` segundos com o `fator` dado (Gás).
func aplicar_slow(fator: float, duracao: float) -> void:
	if duracao <= 0.0:
		return
	_slow_fator = fator
	_slow_restante = maxf(_slow_restante, duracao)


func esta_imobilizado() -> bool:
	return _imobilizado_restante > 0.0


## Multiplicador de velocidade atual: combina o slow do Gás e o Speed Up da Vault.
func fator_velocidade() -> float:
	var f := 1.0
	if _slow_restante > 0.0:
		f *= _slow_fator
	if _speed_restante > 0.0:
		f *= _speed_fator
	return f


## Speed Up (item da Vault): acelera por um tempo (GDD 8).
func aplicar_speed(fator: float, duracao: float) -> void:
	_speed_fator = fator
	_speed_restante = maxf(_speed_restante, duracao)


## Protect (item da Vault): invencível por um tempo, menos contra a Plasma (GDD 8).
func proteger(duracao: float) -> void:
	_protegido_restante = maxf(_protegido_restante, duracao)


func esta_protegido() -> bool:
	return _protegido_restante > 0.0


## Apertar botões reduz o tempo preso (sair da Cova mais rápido — GDD seção 6).
func tentar_escapar(quantidade: float) -> void:
	_imobilizado_restante = maxf(0.0, _imobilizado_restante - quantidade)


## Reseta o combatente pro começo de um round (GDD 12): vida e munição cheias, limpa
## status e estados de combate. A posição é reposicionada pela arena.
func reiniciar() -> void:
	healer = vida_max
	municao = municao_max
	_imobilizado_restante = 0.0
	_slow_restante = 0.0
	_speed_restante = 0.0
	_protegido_restante = 0.0
	_derrubado_restante = 0.0
	_recarga_restante = 0.0
	_cadencia_restante = 0.0
	_soco_cd = 0.0
	_carregando_unit = false
	_impulso = Vector3.ZERO
	velocity = Vector3.ZERO
	healer_mudou.emit(healer, vida_max)
	municao_mudou.emit(municao, municao_max)


## Recupera Healer (capado no máximo). Usado pelo desarme bem-sucedido (GDD 6.2).
func curar(qtd: float) -> void:
	if qtd <= 0.0:
		return
	healer = minf(vida_max, healer + qtd)
	healer_mudou.emit(healer, vida_max)


## Aplica dano ao Healer. Emite os sinais. Chamado pela Mina e pelo combate.
## `tipo_dano` "plasma" ignora o Protect (GDD 8). Tomar dano durante a carga da Unit a
## cancela (a Plasma não dispara — GDD 9).
func receber_dano(qtd: float, tipo_dano: String = "normal") -> void:
	if healer <= 0.0:
		return
	if _protegido_restante > 0.0 and tipo_dano != "plasma":
		return  # Protect bloqueia ataques diretos e armadilhas, mas não a Plasma
	if _carregando_unit:
		_cancelar_carga()
	healer = maxf(0.0, healer - qtd)
	AudioManager.tocar("dano")   # feedback de hit (juice)
	_fx_sangue()                 # respingo vermelho no ponto do golpe
	_fx_hit()                    # "soco" de escala no modelo (impacto legível)
	healer_mudou.emit(healer, vida_max)
	if healer <= 0.0:
		healer_zerou.emit()


## Respingo de sangue (burst curto que cai com gravidade). Montado em código —
## efeito one-shot barato, sem cena própria.
func _fx_sangue() -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.gravity = Vector3(0, -14, 0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	p.mesh = sm
	p.color = Color(0.8, 0.08, 0.08)
	p.add_to_group("fx")
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0.0, 0.6, 0.0)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


## Punch de escala no modelo ao tomar dano (o corpo "sente" o golpe). Usa a escala
## base gravada no mount pra não inflar com hits em sequência.
func _fx_hit() -> void:
	var m := get_node_or_null("Modelo") as Node3D
	if m == null:
		m = get_node_or_null("Malha") as Node3D
	if m == null:
		return
	if not m.has_meta("escala_base"):
		m.set_meta("escala_base", m.scale)
	var base: Vector3 = m.get_meta("escala_base")
	m.scale = base * 1.16
	var tw := create_tween()
	tw.tween_property(m, "scale", base, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Aplica knockback como IMPULSO (empurrão com peso, não teleporte). `forca` ≈ distância
## total que o corpo desliza. Usado pela explosão, pelo Painel e pelo knockdown.
func aplicar_empurrao(direcao: Vector3, forca: float) -> void:
	var d := direcao
	d.y = 0.0
	if d.length() > 0.01:
		_impulso += d.normalized() * forca * IMPULSO_FREIO


## Velocidade extra de knockback deste frame. As subclasses SOMAM isto à velocity
## antes do move_and_slide (assim o empurrão respeita paredes e rampas).
func velocidade_impulso() -> Vector3:
	return _impulso
