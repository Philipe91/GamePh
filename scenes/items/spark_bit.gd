extends Area3D
## Spark Bit (GDD 7.3 / 10): eletricidade viva que dá dano ao toque, com recarga entre
## golpes. Surge sozinho quando faltam 30s pra forçar ação. Só morre com bomba (não
## implementado o "matar" ainda — por ora é um perigo persistente que regenera).

@export var dano: float = 8.0
const RECARGA: float = 0.6   # intervalo entre golpes no mesmo alvo
var _cd: float = 0.0


func _ready() -> void:
	add_to_group("spark_bits")
	body_entered.connect(_ao_corpo_entrar)


func _physics_process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - delta)
		return
	# Dano contínuo em quem ficar em cima.
	for c in get_overlapping_bodies():
		if c.has_method("receber_dano"):
			c.receber_dano(dano)
			_cd = RECARGA
			break


func _ao_corpo_entrar(corpo: Node) -> void:
	if _cd <= 0.0 and corpo.has_method("receber_dano"):
		corpo.receber_dano(dano)
		_cd = RECARGA
