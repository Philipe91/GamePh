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

# Arma de projétil (GDD 7.1). Valores base; viram stats por personagem na Fase 5.
const MUNICAO_MAX: int = 6
const RECARGA_TEMPO: float = 1.5    # s recarregando (vulnerável: não atira)
const CADENCIA: float = 0.28        # s entre tiros
const TIRO_DANO: float = 12.0
const TIRO_RAPIDEZ: float = 22.0    # m/s do projétil
const PROJETIL := preload("res://scenes/projeteis/projetil.tscn")

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


## Troca a cápsula pelo modelo 3D do personagem, se houver (.glb via StatsPersonagem).
## Idempotente: pode ser chamado de novo ao trocar de personagem em runtime.
func _montar_modelo() -> void:
	var antigo := get_node_or_null("Modelo")
	if antigo != null:
		antigo.queue_free()
	var malha := get_node_or_null("Malha")
	if stats == null or stats.cena_modelo == null:
		if malha != null:
			malha.visible = true   # sem modelo: mostra a cápsula placeholder
		return
	if malha != null:
		malha.visible = false      # com modelo: esconde a cápsula
	var m: Node3D = stats.cena_modelo.instantiate()
	m.name = "Modelo"
	add_child(m)
	m.scale = Vector3.ONE * stats.escala_modelo
	m.rotation.y = deg_to_rad(stats.rotacao_modelo_y)
	m.position.y = stats.offset_modelo_y   # pivot nos pés -> desce pro chão


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
	if _carregando_unit:
		_carga_restante = maxf(0.0, _carga_restante - delta)
		if _carga_restante == 0.0:
			_disparar_plasma()


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


## Dispara um tiro na frente (-Z do personagem), se houver munição e cadência liberada.
## Ao zerar a munição, começa a recarga automaticamente.
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
	var p := PROJETIL.instantiate()
	p.dono_id = id_jogador
	p.dano = TIRO_DANO
	p.velocidade = dir * TIRO_RAPIDEZ
	get_parent().add_child(p)
	p.global_position = global_position + dir * 1.1 + Vector3(0.0, 0.0, 0.0)
	p.global_position.y = 1.0
	municao -= 1
	_cadencia_restante = CADENCIA
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
	healer_mudou.emit(healer, vida_max)
	if healer <= 0.0:
		healer_zerou.emit()


## Aplica knockback (empurrão instantâneo). Usado pela explosão da Mina.
func aplicar_empurrao(direcao: Vector3, forca: float) -> void:
	var d := direcao
	d.y = 0.0
	if d.length() > 0.01:
		global_position += d.normalized() * forca
