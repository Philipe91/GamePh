extends CanvasLayer
## HUD do vertical slice (bloco 5): dois Healers, timer e contador de minas.
##
## Só OUVE (por signal); não puxa estado ativamente. A arena chama configurar()
## passando os dois combatentes, e o timer/fim vêm do GameManager.

@onready var barra_p1: ProgressBar = $P1Bar
@onready var barra_p2: ProgressBar = $P2Bar
@onready var lbl_timer: Label = $TimerLabel
@onready var lbl_minas: Label = $MinasLabel
@onready var lbl_municao: Label = $MunicaoLabel
@onready var lbl_unit: Label = $UnitLabel
@onready var lbl_fim: Label = $FimLabel
@onready var lbl_desarme: Label = $DesarmeLabel
@onready var lbl_retomada: Label = $RetomadaLabel

## Setas pra desenhar o Disarming Code (índice = código de direção 0..3).
const SETAS: Array[String] = ["↑", "↓", "←", "→"]

var _jogador: Node = null


func _ready() -> void:
	lbl_fim.visible = false
	GameManager.tempo_mudou.connect(_ao_tempo_mudar)
	GameManager.partida_acabou.connect(_ao_partida_acabar)


## Liga as barras aos Healers e o contador à armadilha selecionada do jogador.
func configurar(p1: Node, p2: Node) -> void:
	_jogador = p1
	p1.healer_mudou.connect(func(atual: float, maximo: float): barra_p1.max_value = maximo; barra_p1.value = atual)
	p2.healer_mudou.connect(func(atual: float, maximo: float): barra_p2.max_value = maximo; barra_p2.value = atual)
	p1.inventario_mudou.connect(_ao_inventario_mudar)
	p1.selecao_mudou.connect(_ao_selecao_mudar)
	p1.municao_mudou.connect(_ao_municao_mudar)
	barra_p1.max_value = p1.vida_max
	barra_p1.value = p1.healer
	barra_p2.max_value = p2.vida_max
	barra_p2.value = p2.healer
	_ao_municao_mudar(p1.municao, p1.municao_max)
	$RadialMenu.configurar(p1)  # a roda lê o estado do jogador
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


func _ao_municao_mudar(atual: int, maximo: int) -> void:
	if _jogador != null and _jogador.esta_recarregando():
		lbl_municao.text = "Munição: recarregando…"
	else:
		lbl_municao.text = "Munição: %d/%d" % [atual, maximo]


## Painel de desarme e prompt de retomada são dinâmicos (timer correndo): leio o estado
## do jogador a cada frame em vez de mil signals por segundo.
func _process(_delta: float) -> void:
	if _jogador == null:
		return
	if _jogador.desarme_ativo():
		var e: Dictionary = _jogador.desarme_estado()
		var seq: Array = e["seq"]
		var idx: int = e["idx"]
		var codigo := ""
		for i in seq.size():
			var s: String = SETAS[int(seq[i])]
			codigo += ("[%s] " % s) if i < idx else ("%s " % s)  # acertados entre colchetes
		lbl_desarme.text = "DESARMAR  %s\n%.1fs" % [codigo.strip_edges(), maxf(0.0, e["tempo"])]
		lbl_desarme.visible = true
	else:
		lbl_desarme.visible = false
	lbl_retomada.visible = _jogador.retomada_disponivel()
	# Unit/Plasma: mostra carga ou estoque quando o jogador tem a Unit.
	if _jogador.tem_unit:
		lbl_unit.visible = true
		if _jogador.esta_carregando_unit():
			lbl_unit.text = "UNIT: carregando %d%%" % int(_jogador.carga_unit_frac() * 100.0)
		else:
			lbl_unit.text = "UNIT x%d (segure U)" % _jogador.plasma_bombs
	else:
		lbl_unit.visible = false


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
