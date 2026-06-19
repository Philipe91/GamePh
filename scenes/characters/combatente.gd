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

# Arma de projétil (GDD 7.1). Valores base; viram stats por personagem na Fase 5.
const MUNICAO_MAX: int = 6
const RECARGA_TEMPO: float = 1.5    # s recarregando (vulnerável: não atira)
const CADENCIA: float = 0.28        # s entre tiros
const TIRO_DANO: float = 12.0
const TIRO_RAPIDEZ: float = 22.0    # m/s do projétil
const PROJETIL := preload("res://scenes/projeteis/projetil.tscn")

## Identidade de time. 1 = jogador, 2 = bot. A Mina usa isto pra saber quem é inimigo.
@export var id_jogador: int = 1

var healer: float = HEALER_MAX
var municao: int = MUNICAO_MAX

# Efeitos de status das armadilhas (Cova/Gás — bloco 2 da Fase 3).
var _imobilizado_restante: float = 0.0   # segundos sem poder andar (Cova/Gás)
var _slow_restante: float = 0.0          # segundos com velocidade reduzida (Gás)
var _slow_fator: float = 1.0             # multiplicador de velocidade enquanto no slow

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


func _ready() -> void:
	add_to_group("combatentes")
	position.y = ALTURA_PISO
	healer = HEALER_MAX
	municao = MUNICAO_MAX
	healer_mudou.emit(healer, HEALER_MAX)
	municao_mudou.emit(municao, MUNICAO_MAX)


## Decai os timers de status e da arma. Roda na base (subclasses só fazem _physics_process).
func _process(delta: float) -> void:
	if _imobilizado_restante > 0.0:
		_imobilizado_restante = maxf(0.0, _imobilizado_restante - delta)
	if _slow_restante > 0.0:
		_slow_restante = maxf(0.0, _slow_restante - delta)
	if _cadencia_restante > 0.0:
		_cadencia_restante = maxf(0.0, _cadencia_restante - delta)
	if _recarga_restante > 0.0:
		_recarga_restante = maxf(0.0, _recarga_restante - delta)
		if _recarga_restante == 0.0:        # recarga terminou: pente cheio
			municao = MUNICAO_MAX
			municao_mudou.emit(municao, MUNICAO_MAX)
	if _soco_cd > 0.0:
		_soco_cd = maxf(0.0, _soco_cd - delta)
	if _derrubado_restante > 0.0:
		_derrubado_restante = maxf(0.0, _derrubado_restante - delta)


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
	alvo.receber_dano(SOCO_DANO)
	if alvo.has_method("derrubar"):
		alvo.derrubar(alvo.global_position - global_position, DERRUBADO_EMPURRAO)


## Sofre um knockdown: empurrão + tempo sem controle (GDD 7.2). Sobrescritível p/ a Unit.
func derrubar(direcao: Vector3, forca: float) -> void:
	_derrubado_restante = DERRUBADO_TEMPO
	aplicar_empurrao(direcao, forca)


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
	municao_mudou.emit(municao, MUNICAO_MAX)
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


## Multiplicador de velocidade atual (1.0 = normal; <1 enquanto no slow).
func fator_velocidade() -> float:
	return _slow_fator if _slow_restante > 0.0 else 1.0


## Apertar botões reduz o tempo preso (sair da Cova mais rápido — GDD seção 6).
func tentar_escapar(quantidade: float) -> void:
	_imobilizado_restante = maxf(0.0, _imobilizado_restante - quantidade)


## Recupera Healer (capado no máximo). Usado pelo desarme bem-sucedido (GDD 6.2).
func curar(qtd: float) -> void:
	if qtd <= 0.0:
		return
	healer = minf(HEALER_MAX, healer + qtd)
	healer_mudou.emit(healer, HEALER_MAX)


## Aplica dano ao Healer. Emite os sinais. Chamado pela Mina e pelo combate.
func receber_dano(qtd: float) -> void:
	if healer <= 0.0:
		return
	healer = maxf(0.0, healer - qtd)
	healer_mudou.emit(healer, HEALER_MAX)
	if healer <= 0.0:
		healer_zerou.emit()


## Aplica knockback (empurrão instantâneo). Usado pela explosão da Mina.
func aplicar_empurrao(direcao: Vector3, forca: float) -> void:
	var d := direcao
	d.y = 0.0
	if d.length() > 0.01:
		global_position += d.normalized() * forca
