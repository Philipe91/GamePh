extends Node
## GameManager — autoload (singleton) do estado da partida.
##
## Partida em ROUNDS (melhor de 3 — GDD 12, [decisão 2026-06-19]): vence quem ganhar 2
## rounds. Cada round tem relógio de 90s; vence o round quem zerar o Healer do oponente,
## ou (no fim do tempo) quem tomou menos dano. Entre rounds há uma pausa curta; a arena
## reseta posições, vida cheia e armadilhas ao ouvir `round_comecou`.
##
## Não referencia player/bot por nome: a arena registra os combatentes em
## iniciar_partida() e o GameManager ouve o sinal healer_zerou de cada um.

## Emitido a cada tick com o tempo restante (a HUD ouve).
signal tempo_mudou(restante: float)
## Emitido ao FIM DA PARTIDA (alguém fez 2 rounds). vencedor_id: 1=jogador, 2=bot.
signal partida_acabou(vencedor_id: int, motivo: String)
## Emitido ao fim de cada ROUND (com o placar atualizado).
signal round_acabou(vencedor_id: int, motivo: String, v1: int, v2: int)
## Emitido no começo de cada round (a arena reseta e a HUD anuncia "ROUND N").
signal round_comecou(numero: int)
## Emitido quando o placar muda (a HUD atualiza).
signal placar_mudou(v1: int, v2: int)
## Emitido uma vez por round quando faltam 30s (a arena solta o Spark Bit — GDD 7.3).
signal faltam_30s

const DURACAO_PARTIDA: float = 90.0
const AVISO_SPARK: float = 30.0
const ROUNDS_PRA_VENCER: int = 2       # melhor de 3
const PAUSA_ENTRE_ROUNDS: float = 2.0  # segundos da tela "ROUND N"

enum Estado { OCIOSO, JOGANDO, ENTRE_ROUNDS, ACABOU }

var tempo_restante: float = DURACAO_PARTIDA
var round_num: int = 1
var v1: int = 0                         # rounds ganhos pelo jogador 1
var v2: int = 0                         # rounds ganhos pelo jogador 2
var _estado: Estado = Estado.OCIOSO
var _combatentes: Array = []
var _avisou_30s: bool = false
var _t_entre_round: float = 0.0

## Hit stop (juice — GDD 13): congela o tempo por um instante em impactos fortes.
var _hit_stop_ativo: bool = false

## Personagens escolhidos na tela de seleção (caminho do .tres). "" = usa o default.
var personagem_jogador: String = ""
var personagem_bot: String = ""

## Modo da partida (GDD 12): "vs_com" (contra o bot) ou "vs_man" (2 jogadores locais).
var modo: String = "vs_com"
## Caminho do mapa escolhido (.tres). "" = padrão.
var mapa: String = ""
## Dificuldade do bot: "facil" | "normal" | "dificil".
var dificuldade: String = "normal"


## Inicia (ou reinicia) a PARTIDA: zera o placar e começa o round 1.
func iniciar_partida(combatentes: Array) -> void:
	_combatentes = combatentes
	for c in _combatentes:
		if c.has_signal("healer_zerou") and not c.healer_zerou.is_connected(_ao_combatente_zerar):
			c.healer_zerou.connect(_ao_combatente_zerar.bind(c))
	v1 = 0
	v2 = 0
	round_num = 1
	placar_mudou.emit(v1, v2)
	_comecar_round()


## Começa o round atual: relógio cheio, avisa a arena (que reseta) e a HUD.
func _comecar_round() -> void:
	tempo_restante = DURACAO_PARTIDA
	_avisou_30s = false
	_estado = Estado.JOGANDO
	round_comecou.emit(round_num)
	tempo_mudou.emit(tempo_restante)


func _process(delta: float) -> void:
	if _estado == Estado.ENTRE_ROUNDS:
		_t_entre_round -= delta
		if _t_entre_round <= 0.0:
			round_num += 1
			_comecar_round()
		return
	if _estado != Estado.JOGANDO:
		return
	tempo_restante = maxf(0.0, tempo_restante - delta)
	tempo_mudou.emit(tempo_restante)
	if not _avisou_30s and tempo_restante <= AVISO_SPARK:
		_avisou_30s = true
		faltam_30s.emit()
	if tempo_restante <= 0.0:
		_decidir_por_tempo()


## Quando um combatente zera, o OUTRO ganha o round.
func _ao_combatente_zerar(combatente: Node) -> void:
	if _estado != Estado.JOGANDO:
		return
	_fim_round(_outro_id(combatente.id_jogador), "Healer zerado")


## No fim do tempo, ganha o round quem tem mais Healer (tomou menos dano). Empate possível.
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
	_fim_round(vencedor, "Tempo esgotado")


## Fecha um round: contabiliza, atualiza o placar e decide se a PARTIDA acabou.
func _fim_round(vencedor_id: int, motivo: String) -> void:
	if vencedor_id == 1:
		v1 += 1
	elif vencedor_id == 2:
		v2 += 1
	placar_mudou.emit(v1, v2)
	round_acabou.emit(vencedor_id, motivo, v1, v2)
	AudioManager.tocar("vitoria")
	if v1 >= ROUNDS_PRA_VENCER or v2 >= ROUNDS_PRA_VENCER:
		_estado = Estado.ACABOU
		var campeao := 1 if v1 > v2 else 2
		Persistencia.registrar_resultado(campeao)  # progressão local (vitórias/derrotas)
		partida_acabou.emit(campeao, motivo)
	else:
		_estado = Estado.ENTRE_ROUNDS
		_t_entre_round = PAUSA_ENTRE_ROUNDS


## Hit stop leve: desacelera o tempo pra `escala` por `duracao` segundos REAIS e volta.
## Dá peso a explosões e knockdowns sem animação nenhuma. Não empilha (o primeiro manda),
## então uma cadeia de bombas em combo gera UM soluço, não uma câmera lenta longa.
func hit_stop(escala: float = 0.15, duracao: float = 0.06) -> void:
	if _hit_stop_ativo:
		return
	_hit_stop_ativo = true
	Engine.time_scale = escala
	# Timer de TEMPO REAL (ignora o time_scale), senão a pausa duraria duracao/escala.
	var t := get_tree().create_timer(duracao, true, false, true)
	t.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_hit_stop_ativo = false)


func _outro_id(id: int) -> int:
	for c in _combatentes:
		if int(c.id_jogador) != id:
			return int(c.id_jogador)
	return 0
