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


func _ready() -> void:
	add_to_group("itens")
	body_entered.connect(_ao_corpo_entrar)


func _ao_corpo_entrar(corpo: Node) -> void:
	if not corpo.has_method("receber_dano"):
		return  # só combatentes pegam item
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
