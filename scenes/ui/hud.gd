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

var _jogador: Node = null


func _ready() -> void:
	lbl_fim.visible = false
	GameManager.tempo_mudou.connect(_ao_tempo_mudar)
	GameManager.partida_acabou.connect(_ao_partida_acabar)


## Liga as barras aos Healers e o contador à armadilha selecionada do jogador.
func configurar(p1: Node, p2: Node) -> void:
	_jogador = p1
	p1.healer_mudou.connect(func(atual: float, _maximo: float): barra_p1.value = atual)
	p2.healer_mudou.connect(func(atual: float, _maximo: float): barra_p2.value = atual)
	p1.inventario_mudou.connect(_ao_inventario_mudar)
	p1.selecao_mudou.connect(_ao_selecao_mudar)
	barra_p1.value = p1.healer
	barra_p2.value = p2.healer
	_atualizar_label_armadilha()


## Mostra "Nome: quantidade" da armadilha selecionada (rodapé esquerdo).
func _atualizar_label_armadilha() -> void:
	if _jogador == null:
		return
	var sel: String = _jogador.selecao
	var qtd: int = int(_jogador.inventario.get(sel, 0))
	var nome: String = _jogador.STATS[sel].nome
	lbl_minas.text = "%s: %d" % [nome, qtd]


func _ao_inventario_mudar(tipo: String, _atual: int, _maximo: int) -> void:
	if _jogador != null and tipo == _jogador.selecao:
		_atualizar_label_armadilha()


func _ao_selecao_mudar(_tipo: String) -> void:
	_atualizar_label_armadilha()


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
