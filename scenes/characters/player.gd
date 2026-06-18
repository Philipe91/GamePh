extends "res://scenes/characters/combatente.gd"
## Player — personagem jogável do vertical slice.
##
## Herda de Combatente (Healer, dano, knockback, grupo). Aqui fica só o que é do
## jogador: movimento LIVRE no plano XZ (WASD + analógico esquerdo) e o plantio de
## Minas (inventário de 4, com recarga em 6s após explodir — GDD seção 6 / bloco 3).

## Emitido quando o inventário de minas muda (pra HUD ouvir no bloco 5).
signal minas_mudou(atual: int, maximo: int)

const VELOCIDADE: float = 7.0       # unidades/seg (3.5 tiles/seg com tile de 2u)
const ZONA_MORTA: float = 0.2       # deadzone do analógico
const MINAS_MAX: int = 4
const TEMPO_RETORNO_MINA: float = 6.0
const CENA_MINA := preload("res://scenes/traps/mina.tscn")

var minas_disponiveis: int = MINAS_MAX

var _plantar_antes: bool = false    # borda do botão de plantar (dispara 1x por toque)


func _ready() -> void:
	super._ready()
	minas_disponiveis = MINAS_MAX
	minas_mudou.emit(minas_disponiveis, MINAS_MAX)


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
	_ler_plantar()


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


## Botão de plantar (Espaço no teclado, A/cross no gamepad), com detecção de borda.
func _ler_plantar() -> void:
	var pressionado := Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if pressionado and not _plantar_antes:
		plantar()
	_plantar_antes = pressionado


## Tenta plantar uma Mina no tile atual do player. Faz o snap pelo GridManager.
## Retorna true se plantou. Público pra entrada e pros testes automatizados.
func plantar() -> bool:
	if minas_disponiveis <= 0:
		return false
	var coord := GridManager.world_to_grid(global_position)
	if not GridManager.pode_plantar(coord):
		return false  # fora do grid ou tile já ocupado
	var mina := CENA_MINA.instantiate()
	mina.dono_id = id_jogador
	mina.coord_grid = coord
	get_parent().add_child(mina)                      # vai pra arena, não fica preso ao player
	mina.global_position = GridManager.grid_to_world(coord)  # snap no centro do tile
	GridManager.registrar_armadilha(coord, id_jogador, "mina", mina)
	mina.consumida.connect(_ao_mina_consumida)
	minas_disponiveis -= 1
	minas_mudou.emit(minas_disponiveis, MINAS_MAX)
	return true


## Quando uma mina explode, ela volta ao inventário após TEMPO_RETORNO_MINA (GDD).
func _ao_mina_consumida() -> void:
	await get_tree().create_timer(TEMPO_RETORNO_MINA).timeout
	minas_disponiveis = mini(minas_disponiveis + 1, MINAS_MAX)
	minas_mudou.emit(minas_disponiveis, MINAS_MAX)
