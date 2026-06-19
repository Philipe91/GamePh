extends Node
## GameManager — autoload (singleton) do estado da partida (GDD seção 4 / bloco 5).
##
## Cuida do relógio de 90s e das regras de vitória:
##  - Vence quem zerar o Healer do oponente.
##  - Se o tempo acabar, vence quem tomou MENOS dano (maior Healer); empate possível.
##
## Não referencia player/bot por nome: a arena registra os combatentes em
## iniciar_partida() e o GameManager ouve o sinal healer_zerou de cada um.

## Emitido a cada tick com o tempo restante (a HUD ouve).
signal tempo_mudou(restante: float)
## Emitido uma vez ao fim. vencedor_id: 1=jogador, 2=bot, 0=empate.
signal partida_acabou(vencedor_id: int, motivo: String)
## Emitido uma vez quando faltam 30s (a arena solta o Spark Bit — GDD 7.3).
signal faltam_30s

const DURACAO_PARTIDA: float = 90.0
const AVISO_SPARK: float = 30.0

enum Estado { OCIOSO, JOGANDO, ACABOU }

var tempo_restante: float = DURACAO_PARTIDA
var _estado: Estado = Estado.OCIOSO
var _combatentes: Array = []
var _avisou_30s: bool = false


## Inicia (ou reinicia) a partida com a lista de combatentes (nós com Healer e id).
func iniciar_partida(combatentes: Array) -> void:
	_combatentes = combatentes
	for c in _combatentes:
		if c.has_signal("healer_zerou") and not c.healer_zerou.is_connected(_ao_combatente_zerar):
			c.healer_zerou.connect(_ao_combatente_zerar.bind(c))
	tempo_restante = DURACAO_PARTIDA
	_estado = Estado.JOGANDO
	_avisou_30s = false
	tempo_mudou.emit(tempo_restante)


func _process(delta: float) -> void:
	if _estado != Estado.JOGANDO:
		return
	tempo_restante = maxf(0.0, tempo_restante - delta)
	tempo_mudou.emit(tempo_restante)
	if not _avisou_30s and tempo_restante <= AVISO_SPARK:
		_avisou_30s = true
		faltam_30s.emit()
	if tempo_restante <= 0.0:
		_decidir_por_tempo()


## Quando um combatente zera, vence o outro time.
func _ao_combatente_zerar(combatente: Node) -> void:
	if _estado != Estado.JOGANDO:
		return
	_terminar(_outro_id(combatente.id_jogador), "Healer zerado")


## No fim do tempo, vence quem tem mais Healer (tomou menos dano). Empate se igual.
func _decidir_por_tempo() -> void:
	var melhor: Node = null
	var empate := false
	for c in _combatentes:
		if melhor == null or c.healer > melhor.healer:
			melhor = c
			empate = false
		elif is_equal_approx(c.healer, melhor.healer):
			empate = true
	var vencedor := 0 if (empate or melhor == null) else int(melhor.id_jogador)
	_terminar(vencedor, "Tempo esgotado")


func _terminar(vencedor_id: int, motivo: String) -> void:
	_estado = Estado.ACABOU
	partida_acabou.emit(vencedor_id, motivo)


func _outro_id(id: int) -> int:
	for c in _combatentes:
		if int(c.id_jogador) != id:
			return int(c.id_jogador)
	return 0
