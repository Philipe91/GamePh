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


## Modelo placeholder padrão (Kenney) usado em JOGO até cada personagem ter o seu próprio.
const MODELO_PADRAO_PATH := "res://assets/models/kenney/Character/Character.gltf"
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
		# Auto-fit: mede a AABB crua do modelo e escala pra ALTURA_MODELO_ALVO.
		var alt := _altura_aabb(m)
		escala = (ALTURA_MODELO_ALVO / alt) if alt > 0.01 else 1.0
	m.scale = Vector3.ONE * escala
	m.rotation.y = deg_to_rad(rot)
	m.position.y = offset           # pivot nos pés -> desce pro chão
	# Tinta de time SÓ no modelo fallback (os dois usariam o mesmo boneco). Modelos
	# próprios do roster (KayKit) mantêm a textura — o anel colorido separa os times.
	if stats == null or stats.cena_modelo == null:
		_tingir_modelo(m)
	_configurar_animacao(m)
	_montar_anel_time()


# ─────────────── Animação do modelo (idle / correr / derrubado) ───────────────

var _anim: AnimationPlayer = null
var _anim_idle: String = ""
var _anim_mover: String = ""
var _anim_derrubado: String = ""
var _anim_morte: String = ""
var _anim_vitoria: String = ""
var _anim_atual: String = ""
var _comemorar_ate_ms: int = 0   # comemora (fim de round) até este tick


## Acha o AnimationPlayer do modelo e resolve os nomes das animações (KayKit ou
## qualquer glb: procura por nome exato e cai pra substring, ex. "Rig|Idle").
func _configurar_animacao(m: Node3D) -> void:
	_anim = null
	_anim_atual = ""
	var achados := m.find_children("*", "AnimationPlayer", true, false)
	if achados.is_empty():
		return
	_anim = achados[0]
	_anim_idle = _primeira_anim(["Idle", "Idle_A"])
	_anim_mover = _primeira_anim(["Running_A", "Running_B", "Run", "Walking_A", "Walk"])
	_anim_derrubado = _primeira_anim(["Hit_A", "Hit_B", "Death_A"])
	_anim_morte = _primeira_anim(["Death_A", "Death_B", "Death"])
	_anim_vitoria = _primeira_anim(["Cheer", "Victory", "Wave", "Jump"])
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
	elif Vector2(velocity.x, velocity.z).length() > 0.8:
		alvo = _anim_mover
	if alvo != "" and alvo != _anim_atual:
		_anim_atual = alvo
		_anim.play(alvo, 0.2)


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
	_atualizar_animacao()


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
	municao_mudou.emit(municao, municao_max)
	if municao <= 0:
		_recarga_restante = RECARGA_TEMPO


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
