extends Area3D
## Mina — a única armadilha do vertical slice (GDD seção 6).
##
## Comportamento (CLAUDE.md bloco 3):
##  - Plantada pelo dono no centro do tile (o snap é feito por quem planta).
##  - Arma após 0,5s; antes disso é inerte e fica visível só como aviso.
##  - Quando um inimigo (id diferente do dono) entra no tile, explode:
##    dano + knockback em todos os combatentes no raio (inclui o dono — GDD).
##  - Acoplamento solto: NÃO referencia o Player. Detecta corpos pela Area3D e
##    chama receber_dano/aplicar_empurrao via has_method; acha alvos do raio pelo
##    grupo "combatentes".
##
## Obs. de design: o GDD lista só "dano" pra Mina, mas o CLAUDE.md do slice pede
## dano + knockback pra dar feel. Seguimos o CLAUDE.md (spec explícita da tarefa).

## Avisa o dono que a mina saiu de jogo (pra recarregar o inventário em 6s).
signal consumida

const TEMPO_ARMA: float = 0.5       # atraso até armar (inerte antes disso)
const DANO: float = 20.0
const RAIO_EXPLOSAO: float = 2.2    # alcance estreito (GDD)
const FORCA_KNOCKBACK: float = 3.5
const ALTURA: float = 0.1

enum Estado { ARMANDO, ARMADA, EXPLODIDA }

## Time dono da mina (não dispara nas próprias pernas).
@export var dono_id: int = 1
## Tile onde foi plantada (pra liberar a ocupação no GridManager ao explodir).
var coord_grid: Vector2i = Vector2i.ZERO

var _estado: Estado = Estado.ARMANDO
@onready var marca: MeshInstance3D = $Marca


func _ready() -> void:
	position.y = ALTURA
	# Material próprio por instância (não compartilhar a cor entre minas).
	marca.material_override = marca.material_override.duplicate()
	_pintar(Color(1.0, 0.55, 0.1, 0.9), 0.8)  # armando: laranja visível (aviso)
	body_entered.connect(_ao_corpo_entrar)
	await get_tree().create_timer(TEMPO_ARMA).timeout
	if _estado == Estado.ARMANDO:
		_estado = Estado.ARMADA
		# Armada: discreta, quase invisível pro inimigo (GDD).
		_pintar(Color(0.2, 0.6, 1.0, 0.25), 0.2)


func _ao_corpo_entrar(corpo: Node) -> void:
	if _estado != Estado.ARMADA:
		return
	if not corpo.has_method("receber_dano"):
		return
	if corpo.get("id_jogador") == dono_id:
		return  # o dono não dispara a própria mina
	_detonar()


func _detonar() -> void:
	_estado = Estado.EXPLODIDA
	GridManager.remover_armadilha(coord_grid)
	consumida.emit()
	# Dano + knockback em todos os combatentes dentro do raio (inclui o dono — GDD).
	for c in get_tree().get_nodes_in_group("combatentes"):
		if not is_instance_valid(c):
			continue
		if global_position.distance_to(c.global_position) > RAIO_EXPLOSAO:
			continue
		if c.has_method("receber_dano"):
			c.receber_dano(DANO)
		if c.has_method("aplicar_empurrao"):
			c.aplicar_empurrao(c.global_position - global_position, FORCA_KNOCKBACK)
	_mostrar_explosao()


## Flash visual simples da explosão e some.
func _mostrar_explosao() -> void:
	_pintar(Color(1.0, 0.9, 0.4, 1.0), 3.0)
	marca.scale = Vector3(4.0, 1.0, 4.0)
	await get_tree().create_timer(0.35).timeout
	queue_free()


func _pintar(cor: Color, energia: float) -> void:
	var mat: StandardMaterial3D = marca.material_override
	mat.albedo_color = cor
	mat.emission = Color(cor.r, cor.g, cor.b)
	mat.emission_energy_multiplier = energia
