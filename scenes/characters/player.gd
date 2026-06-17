extends CharacterBody3D
## Player — personagem jogável do vertical slice.
##
## Movimento LIVRE no plano XZ (não travado em célula; o snap só acontece ao
## plantar armadilha — GDD seção 5), por WASD e pelo analógico esquerdo do gamepad.
## Cápsula placeholder colorida + "nariz" que indica a frente. Healer = barra de
## vida (GDD seção 7.3): começa em 100, emite sinal ao mudar e ao zerar.

## Emitido quando o Healer muda (pra HUD ouvir, comunicação por signal).
signal healer_mudou(atual: float, maximo: float)
## Emitido quando o Healer chega a zero (fim de partida desse jogador).
signal healer_zerou

const VELOCIDADE: float = 7.0           # unidades/seg (3.5 tiles/seg com tile de 2u)
const HEALER_MAX: float = 100.0
const ALTURA_PISO: float = 1.0          # centro da cápsula p/ os pés ficarem no chão (y=0)
const COR: Color = Color(0.2, 0.6, 1.0) # azul neon = jogador 1 (GDD seção 11, radar)
const ZONA_MORTA: float = 0.2           # deadzone do analógico

@export var id_jogador: int = 1

var healer: float = HEALER_MAX


func _ready() -> void:
	position.y = ALTURA_PISO
	healer = HEALER_MAX
	healer_mudou.emit(healer, HEALER_MAX)


func _physics_process(_delta: float) -> void:
	var dir := _obter_direcao()
	velocity.x = dir.x * VELOCIDADE
	velocity.z = dir.y * VELOCIDADE
	velocity.y = 0.0
	move_and_slide()
	position.y = ALTURA_PISO  # trava no plano do chão (movimento top-down)
	# Vira pra direção do movimento (frente = -Z). Útil p/ mira e Painel de Força depois.
	if dir.length() > 0.01:
		var alvo := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, alvo, 0.25)


## Lê WASD + analógico esquerdo (1º gamepad). Retorna Vector2 (x=lateral, y=frente/trás),
## com magnitude no máximo 1. y negativo = "pra cima na tela" (-Z no mundo).
func _obter_direcao() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	var gx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var gy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(gx) > ZONA_MORTA:
		dir.x += gx
	if absf(gy) > ZONA_MORTA:
		dir.y += gy
	return dir.limit_length(1.0)


## Aplica dano ao Healer. Emite os sinais. Chamado pela Mina (bloco 3) e pelo combate.
func receber_dano(qtd: float) -> void:
	if healer <= 0.0:
		return
	healer = maxf(0.0, healer - qtd)
	healer_mudou.emit(healer, HEALER_MAX)
	if healer <= 0.0:
		healer_zerou.emit()


## Aplica knockback (empurrão instantâneo). Usado pela explosão da Mina.
func aplicar_empurrao(direcao: Vector3, forca: float) -> void:
	var d := direcao
	d.y = 0.0
	if d.length() > 0.01:
		global_position += d.normalized() * forca
