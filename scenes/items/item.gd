extends Area3D
## Item da Vault (GDD 8). Pega ao encostar (qualquer combatente) e aplica o efeito.
## Acoplamento solto: age por has_method, nunca por nome de nó.

## "armadilha" | "speed" | "protect" | "healer" | "unit".
@export var tipo: String = "healer"
## Para tipo "armadilha": qual armadilha entra no inventário.
@export var tipo_armadilha: String = "mina"

const CURA: float = 40.0
const SPEED_FATOR: float = 2.0
const SPEED_DUR: float = 20.0
const PROTECT_DUR: float = 8.0

## Cor por tipo (leitura instantânea do drop, estilo arcade).
const CORES := {
	"healer": Color(0.25, 1.0, 0.45),
	"speed": Color(1.0, 0.9, 0.2),
	"protect": Color(0.3, 0.6, 1.0),
	"unit": Color(1.0, 0.3, 0.9),
	"armadilha": Color(1.0, 0.55, 0.15),
}

var _t: float = 0.0
## Base do bob capturada no 1º frame de _process — no _ready a posição ainda não foi
## definida (a Vault/caixa posiciona DEPOIS do add_child).
var _y_base: float = -1.0e9


func _ready() -> void:
	add_to_group("itens")
	body_entered.connect(_ao_corpo_entrar)
	# Caixinha na cor do tipo, com brilho (era um cubo branco sem material).
	var mi := get_node_or_null("Malha") as MeshInstance3D
	if mi != null:
		var cor: Color = CORES.get(tipo, Color.WHITE)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cor
		mat.emission_enabled = true
		mat.emission = cor
		mat.emission_energy_multiplier = 1.2
		mi.material_override = mat


## Gira e flutua (feedback de "isso é coletável" — GDD 13).
func _process(delta: float) -> void:
	if _y_base < -1.0e8:
		_y_base = position.y
	_t += delta
	rotate_y(delta * 2.2)
	position.y = _y_base + 0.15 * sin(_t * 3.0)


func _ao_corpo_entrar(corpo: Node) -> void:
	if not corpo.has_method("receber_dano"):
		return  # só combatentes pegam item
	AudioManager.tocar("item")
	_aplicar(corpo)
	queue_free()


func _aplicar(c: Node) -> void:
	match tipo:
		"speed":
			if c.has_method("aplicar_speed"):
				c.aplicar_speed(SPEED_FATOR, SPEED_DUR)
		"protect":
			if c.has_method("proteger"):
				c.proteger(PROTECT_DUR)
		"healer":
			if c.has_method("curar"):
				c.curar(CURA)
		"unit":
			if c.has_method("conceder_unit"):
				c.conceder_unit(1)
		"armadilha":
			if c.has_method("ganhar_armadilha"):
				c.ganhar_armadilha(tipo_armadilha)
