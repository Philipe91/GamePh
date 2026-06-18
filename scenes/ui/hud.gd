extends CanvasLayer
## HUD do vertical slice (bloco 5): dois Healers, timer e contador de minas.
##
## Só OUVE (por signal); não puxa estado ativamente. A arena chama configurar()
## passando os dois combatentes, e o timer/fim vêm do GameManager.

@onready var barra_p1: ProgressBar = $P1Bar
@onready var barra_p2: ProgressBar = $P2Bar
@onready var lbl_timer: Label = $TimerLabel
@onready var lbl_minas: Label = $MinasLabel
@onready var lbl_fim: Label = $FimLabel


func _ready() -> void:
	lbl_fim.visible = false
	GameManager.tempo_mudou.connect(_ao_tempo_mudar)
	GameManager.partida_acabou.connect(_ao_partida_acabar)


## Liga as barras aos Healers e o contador às minas do jogador.
func configurar(p1: Node, p2: Node) -> void:
	p1.healer_mudou.connect(func(atual: float, _maximo: float): barra_p1.value = atual)
	p2.healer_mudou.connect(func(atual: float, _maximo: float): barra_p2.value = atual)
	p1.minas_mudou.connect(func(atual: int, _maximo: int): lbl_minas.text = "Minas: %d" % atual)
	barra_p1.value = p1.healer
	barra_p2.value = p2.healer
	lbl_minas.text = "Minas: %d" % p1.minas_disponiveis


func _ao_tempo_mudar(restante: float) -> void:
	lbl_timer.text = "%d" % ceili(restante)


func _ao_partida_acabar(vencedor_id: int, motivo: String) -> void:
	if vencedor_id == 0:
		lbl_fim.text = "EMPATE\n(%s)" % motivo
	elif vencedor_id == 1:
		lbl_fim.text = "VOCÊ VENCEU\n(%s)" % motivo
	else:
		lbl_fim.text = "VOCÊ PERDEU\n(%s)" % motivo
	lbl_fim.visible = true
