extends Area3D
## Spark Bit (GDD 7.3 / 10): eletricidade viva que dá dano ao toque. Surge sozinho
## quando faltam 30s pra forçar ação.
##
## Fiel ao manual: ataque direto NÃO o destrói (projétil não colide com Area3D) —
## só EXPLOSÃO mata (entra no grupo "destrutiveis", que as explosões varrem) — e ele
## REGENERA um tempo depois. Sendo "forma viva", vagueia devagar pela arena.

@export var dano: float = 8.0
const RECARGA: float = 0.6        # intervalo entre golpes no mesmo alvo
const VIDA: float = 10.0          # uma explosão de armadilha mata (dano >= 10)
const RENASCE_APOS: float = 8.0   # segundos morto até regenerar (manual: regenera)
const RAPIDEZ: float = 2.2        # vagueio lento (dá pra fugir andando)
const TROCA_RUMO: float = 1.6     # segundos até sortear um rumo novo

var _cd: float = 0.0
var _vida: float = VIDA
var _morto: bool = false
var _rumo: Vector3 = Vector3.ZERO
var _t_rumo: float = 0.0


func _ready() -> void:
	add_to_group("spark_bits")
	add_to_group("destrutiveis")   # explosões de armadilha varrem este grupo (GDD 10)
	body_entered.connect(_ao_corpo_entrar)


func esta_morto() -> bool:
	return _morto


## Dano recebido. Na prática só explosões chegam aqui (projéteis detectam CORPOS e o
## Spark Bit é uma Area) — exatamente a regra do manual: "só morre com bomba".
func receber_dano(qtd: float, _tipo_dano: String = "normal") -> void:
	if _morto:
		return
	_vida -= qtd
	if _vida <= 0.0:
		_morrer()


## Some (sem dar dano nem aparecer) e agenda o renascimento (regenera com o tempo).
func _morrer() -> void:
	_morto = true
	visible = false
	set_deferred("monitoring", false)
	get_tree().create_timer(RENASCE_APOS).timeout.connect(_renascer)


func _renascer() -> void:
	if not is_inside_tree():
		return
	_morto = false
	_vida = VIDA
	visible = true
	set_deferred("monitoring", true)


func _physics_process(delta: float) -> void:
	if _morto:
		return
	# Vagueio: troca de rumo de tempos em tempos; não sai do grid da arena.
	_t_rumo -= delta
	if _t_rumo <= 0.0:
		_t_rumo = TROCA_RUMO
		var ang := randf() * TAU
		_rumo = Vector3(cos(ang), 0.0, sin(ang))
	var novo := global_position + _rumo * RAPIDEZ * delta
	if GridManager.dentro_do_grid(GridManager.world_to_grid(novo)):
		global_position = novo
	else:
		_t_rumo = 0.0   # bateu na borda: sorteia outro rumo no próximo frame
	# Dano contínuo em quem ficar em cima (com recarga entre golpes).
	if _cd > 0.0:
		_cd = maxf(0.0, _cd - delta)
		return
	for c in get_overlapping_bodies():
		if c.has_method("receber_dano"):
			c.receber_dano(dano)
			_cd = RECARGA
			break


func _ao_corpo_entrar(corpo: Node) -> void:
	if not _morto and _cd <= 0.0 and corpo.has_method("receber_dano"):
		corpo.receber_dano(dano)
		_cd = RECARGA
