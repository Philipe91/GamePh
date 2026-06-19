extends Area3D
## Ponte / passarela (GDD 9 / 11): ponto de evasão da Plasma. A Plasma se dissolve ao
## atingir a ponte, e a ponte quebra junto (cor "azul claro" no radar). Sem dano.

func _ready() -> void:
	add_to_group("pontes")


## Destrói a ponte (a Plasma a derruba ao acertar — GDD 9).
func quebrar() -> void:
	queue_free()
