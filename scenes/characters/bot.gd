extends "res://scenes/characters/combatente.gd"
## Bot inimigo — vertical slice (bloco 4).
##
## Persegue o player em linha simples (sem pathfinding, sem desviar de armadilha —
## a IA de armadilha vem em fases futuras). Como anda em cima das minas, é ele quem
## faz o loop do slice virar jogo. Herda de Combatente (Healer, dano, knockback).

const VELOCIDADE: float = 5.0       # um pouco mais lento que o player (foge dá certo)
const DIST_PARAR: float = 1.2       # encostou no alvo, para de empurrar

var _alvo: Node3D = null


func _physics_process(_delta: float) -> void:
	if _alvo == null or not is_instance_valid(_alvo):
		_alvo = _achar_alvo()
	if _alvo == null:
		return
	var para := _alvo.global_position - global_position
	para.y = 0.0
	if para.length() > DIST_PARAR:
		var d := para.normalized()
		velocity.x = d.x * VELOCIDADE
		velocity.z = d.z * VELOCIDADE
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = 0.0
	move_and_slide()
	position.y = ALTURA_PISO
	if para.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 0.2)


## Acha o primeiro combatente de outro time (o player). Sem acoplamento por nome.
func _achar_alvo() -> Node3D:
	for c in get_tree().get_nodes_in_group("combatentes"):
		if c == self:
			continue
		if c.get("id_jogador") != id_jogador:
			return c
	return null
