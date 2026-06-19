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

const HEALER_MAX: float = 100.0
const ALTURA_PISO: float = 1.0  # centro da cápsula p/ os pés ficarem no chão (y=0)

## Identidade de time. 1 = jogador, 2 = bot. A Mina usa isto pra saber quem é inimigo.
@export var id_jogador: int = 1

var healer: float = HEALER_MAX

# Efeitos de status das armadilhas (Cova/Gás — bloco 2 da Fase 3).
var _imobilizado_restante: float = 0.0   # segundos sem poder andar (Cova/Gás)
var _slow_restante: float = 0.0          # segundos com velocidade reduzida (Gás)
var _slow_fator: float = 1.0             # multiplicador de velocidade enquanto no slow


func _ready() -> void:
	add_to_group("combatentes")
	position.y = ALTURA_PISO
	healer = HEALER_MAX
	healer_mudou.emit(healer, HEALER_MAX)


## Decai os timers de status. Roda na base (subclasses só sobrescrevem _physics_process).
func _process(delta: float) -> void:
	if _imobilizado_restante > 0.0:
		_imobilizado_restante = maxf(0.0, _imobilizado_restante - delta)
	if _slow_restante > 0.0:
		_slow_restante = maxf(0.0, _slow_restante - delta)


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
